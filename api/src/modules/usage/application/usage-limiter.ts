import type { PlanLimits, PlansConfig } from '../domain/plans.js';
import { costaRicaDay, nextCostaRicaMidnight } from '../domain/costa-rica-day.js';
import { UsageStoreError, type UsageStore } from './usage-store.js';

export interface UsageUser {
  id: string;
  plan: string;
}

export interface UsageSnapshot {
  plan: string;
  used: number;
  limit: number;
  remaining: number;
  /** Next midnight in Costa Rica, ISO 8601 in UTC. */
  resetsAt: string;
}

export type UsageLimitError =
  | { reason: 'daily_limit'; resetsAt: string }
  | { reason: 'rate_limit'; retryAfterSeconds: number };

export class UsageLimitExceededError extends Error {
  constructor(readonly limit: UsageLimitError) {
    super(`Usage limit reached: ${limit.reason}`);
    this.name = 'UsageLimitExceededError';
  }
}

export interface UsageLimiter {
  snapshot(user: UsageUser): Promise<UsageSnapshot>;
  reserveAttempt(user: UsageUser): Promise<void>;
  /** Count only completed replies. A write failure is logged and reflected in health. */
  recordInteraction(user: UsageUser): Promise<UsageSnapshot | undefined>;
  /** Reports whether the latest usage write succeeded for the health endpoint. */
  isCounting(): boolean;
}

export function createUsageLimiter(
  plans: PlansConfig,
  store: UsageStore,
  now: () => Date = () => new Date(),
): UsageLimiter {
  const recentAttempts = new Map<string, number[]>();
  let lastCountFailed = false;

  function rateLimitFor(user: UsageUser): PlanLimits['rateLimit'] {
    // An unknown plan falls back to personal instead of having no limit.
    return (plans[user.plan] ?? plans.personal!).rateLimit;
  }

  async function dailyCap(user: UsageUser): Promise<number> {
    const cap = (await store.dailyCap(user.plan)) ?? (await store.dailyCap('personal'));
    if (cap === undefined) throw new UsageStoreError();
    return cap;
  }

  function snapshotOf(user: UsageUser, used: number, limit: number): UsageSnapshot {
    return {
      plan: user.plan,
      used,
      limit,
      remaining: Math.max(limit - used, 0),
      resetsAt: nextCostaRicaMidnight(now()).toISOString(),
    };
  }

  async function snapshot(user: UsageUser): Promise<UsageSnapshot> {
    const [used, limit] = await Promise.all([
      store.used(user.id, costaRicaDay(now())),
      dailyCap(user),
    ]);
    return snapshotOf(user, used, limit);
  }

  return {
    snapshot,

    async reserveAttempt(user) {
      const { remaining, resetsAt } = await snapshot(user);
      if (remaining === 0) throw new UsageLimitExceededError({ reason: 'daily_limit', resetsAt });

      const { requests, windowSeconds } = rateLimitFor(user);
      const current = now().getTime();
      const windowStart = current - windowSeconds * 1000;
      const attempts = (recentAttempts.get(user.id) ?? []).filter((time) => time > windowStart);

      if (attempts.length >= requests) {
        const retryAfterSeconds = Math.ceil((attempts[0]! - windowStart) / 1000);
        recentAttempts.set(user.id, attempts);
        throw new UsageLimitExceededError({ reason: 'rate_limit', retryAfterSeconds });
      }
      recentAttempts.set(user.id, [...attempts, current]);
    },

    async recordInteraction(user) {
      try {
        const [used, limit] = await Promise.all([
          store.record(user.id, costaRicaDay(now())),
          dailyCap(user),
        ]);
        lastCountFailed = false;
        return snapshotOf(user, used, limit);
      } catch {
        lastCountFailed = true;
        return undefined;
      }
    },

    isCounting: () => !lastCountFailed,
  };
}
