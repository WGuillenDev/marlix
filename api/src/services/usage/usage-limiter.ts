// Daily and rate limits per user (S2-6). The daily count and cap are in the
// database (S4-13), so a restart or deploy does not reset them. The rate
// window is short and stays in memory: a restart only gives more room.
import type { PlanLimits, PlansConfig } from '../../config/plans.js';
import { costaRicaDay, nextCostaRicaMidnight } from './costa-rica-day.js';
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

/** Thrown when a message would go over a limit. Mapped to 429 by the error handler. */
export class UsageLimitExceededError extends Error {
  constructor(readonly limit: UsageLimitError) {
    super(`Usage limit reached: ${limit.reason}`);
    this.name = 'UsageLimitExceededError';
  }
}

export interface UsageLimiter {
  snapshot(user: UsageUser): Promise<UsageSnapshot>;
  /**
   * Called before the model: throws if the user is at the daily cap or
   * sending too fast, otherwise takes one slot of the rate window. It fails
   * (UsageStoreError) if the count cannot be read, so nothing reaches the model.
   */
  reserveAttempt(user: UsageUser): Promise<void>;
  /**
   * Called after a successful reply: only those count against the cap. Never
   * fails: a count that cannot be saved is logged by the store and the reply
   * is still delivered, so this returns undefined instead of the usage.
   */
  recordInteraction(user: UsageUser): Promise<UsageSnapshot | undefined>;
}

export function createUsageLimiter(
  plans: PlansConfig,
  store: UsageStore,
  now: () => Date = () => new Date(),
): UsageLimiter {
  const recentAttempts = new Map<string, number[]>();

  function rateLimitFor(user: UsageUser): PlanLimits['rateLimit'] {
    // An unknown plan falls back to personal instead of having no limit.
    return (plans[user.plan] ?? plans.personal!).rateLimit;
  }

  async function dailyCap(user: UsageUser): Promise<number> {
    const cap = (await store.dailyCap(user.plan)) ?? (await store.dailyCap('personal'));
    // The seed of docs/schema.sql always has the personal plan.
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
        return snapshotOf(user, used, limit);
      } catch {
        return undefined;
      }
    },
  };
}
