// Daily and rate limits per user (S2-6). Counters are kept in memory until
// Sprint 4 stores them in daily_usage: a restart or deploy resets them, which
// can only give someone more room, never less.
import type { PlanLimits, PlansConfig } from '../../config/plans.js';
import { costaRicaDay, nextCostaRicaMidnight } from './costa-rica-day.js';

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
  snapshot(user: UsageUser): UsageSnapshot;
  /**
   * Called before the model: throws if the user is at the daily cap or
   * sending too fast, otherwise takes one slot of the rate window.
   */
  reserveAttempt(user: UsageUser): void;
  /** Called after a successful reply: only those count against the cap. */
  recordInteraction(user: UsageUser): void;
}

export function createUsageLimiter(
  plans: PlansConfig,
  now: () => Date = () => new Date(),
): UsageLimiter {
  const daily = new Map<string, { day: string; used: number }>();
  const recentAttempts = new Map<string, number[]>();

  function limitsFor(user: UsageUser): PlanLimits {
    // An unknown plan falls back to personal instead of having no limit.
    return plans[user.plan] ?? plans.personal!;
  }

  function usedToday(user: UsageUser): number {
    const entry = daily.get(user.id);
    return entry?.day === costaRicaDay(now()) ? entry.used : 0;
  }

  function snapshot(user: UsageUser): UsageSnapshot {
    const limit = limitsFor(user).dailyInteractions;
    const used = usedToday(user);
    return {
      plan: user.plan,
      used,
      limit,
      remaining: Math.max(limit - used, 0),
      resetsAt: nextCostaRicaMidnight(now()).toISOString(),
    };
  }

  return {
    snapshot,

    reserveAttempt(user) {
      const { remaining, resetsAt } = snapshot(user);
      if (remaining === 0) throw new UsageLimitExceededError({ reason: 'daily_limit', resetsAt });

      const { requests, windowSeconds } = limitsFor(user).rateLimit;
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

    recordInteraction(user) {
      daily.set(user.id, { day: costaRicaDay(now()), used: usedToday(user) + 1 });
    },
  };
}
