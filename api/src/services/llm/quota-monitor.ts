// Remembers how much of Groq's daily request quota is left (S7-6), from the
// rate-limit headers of the answers the backend already gets. It makes no
// calls of its own, so watching the quota never spends any.

/** What Groq's answer says about one model's daily requests. */
export interface QuotaReading {
  limit: number;
  remaining: number;
  /** Seconds until the daily window resets. */
  resetsInSeconds: number;
}

export interface QuotaMonitor {
  record(model: string, reading: QuotaReading): void;
  /** True when any model has this fraction of its daily requests left, or less. */
  isLow(): boolean;
}

/** Alert when 20% or less of a model's daily requests are left. */
export const QUOTA_LOW_FRACTION = 0.2;

export function createQuotaMonitor(now: () => number = Date.now): QuotaMonitor {
  const readings = new Map<string, QuotaReading & { expiresAt: number }>();

  return {
    record(model, reading) {
      readings.set(model, {
        ...reading,
        expiresAt: now() + reading.resetsInSeconds * 1000,
      });
    },
    isLow() {
      for (const [model, reading] of readings) {
        // After the reset the old reading says nothing about the new day.
        if (reading.expiresAt <= now()) {
          readings.delete(model);
        } else if (reading.remaining <= reading.limit * QUOTA_LOW_FRACTION) {
          return true;
        }
      }
      return false;
    },
  };
}
