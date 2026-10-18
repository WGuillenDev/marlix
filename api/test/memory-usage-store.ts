import type { UsageStore } from '../src/services/usage/usage-store.js';
import { UsageStoreError } from '../src/services/usage/usage-store.js';

/** A UsageStore that keeps the counters and caps in memory, like the two tables. */
export function createMemoryUsageStore(caps: Record<string, number> = { personal: 1000 }) {
  const counts = new Map<string, number>();
  const failing = { reads: false, writes: false };

  const store: UsageStore = {
    async used(userId, day) {
      if (failing.reads) throw new UsageStoreError();
      return counts.get(`${userId}|${day}`) ?? 0;
    },

    async dailyCap(plan) {
      if (failing.reads) throw new UsageStoreError();
      return caps[plan];
    },

    async record(userId, day) {
      if (failing.writes) throw new UsageStoreError();
      const key = `${userId}|${day}`;
      const total = (counts.get(key) ?? 0) + 1;
      counts.set(key, total);
      return total;
    },
  };

  return { store, caps, counts, failing };
}
