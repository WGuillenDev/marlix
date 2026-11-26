// Read quota from existing responses so monitoring does not spend it.

export interface QuotaReading {
  limit: number;
  remaining: number;
  resetsInSeconds: number;
}

export interface QuotaMonitor {
  record(model: string, reading: QuotaReading): void;
  isLow(): boolean;
}

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
