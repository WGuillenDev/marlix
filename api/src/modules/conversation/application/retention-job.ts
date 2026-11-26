import type { MessageStore } from './message-store.js';

const DAY_MS = 86_400_000;
const DEFAULT_SWEEP_EVERY_MS = 60 * 60_000;

export interface RetentionJobOptions {
  messages: MessageStore;
  retentionDays: number;
  sweepEveryMs?: number;
  now?: () => Date;
}

export interface RetentionJob {
  /** Deletes the expired messages and returns how many. Never throws: the next sweep retries. */
  sweep(): Promise<number>;
  /** The retention timer does not keep the process alive. */
  start(): void;
  stop(): void;
}

export function createRetentionJob({
  messages,
  retentionDays,
  sweepEveryMs = DEFAULT_SWEEP_EVERY_MS,
  now = () => new Date(),
}: RetentionJobOptions): RetentionJob {
  let timer: NodeJS.Timeout | undefined;

  async function sweep(): Promise<number> {
    try {
      const deleted = await messages.deleteOlderThan(
        new Date(now().getTime() - retentionDays * DAY_MS),
      );
      if (deleted > 0) console.log(`Retention: ${deleted} expired messages deleted`);
      return deleted;
    } catch (error) {
      console.warn(`Retention sweep failed (${(error as Error).name})`);
      return 0;
    }
  }

  return {
    sweep,

    start() {
      if (timer) return;
      timer = setInterval(() => void sweep(), sweepEveryMs);
      timer.unref();
      void sweep();
    },

    stop() {
      clearInterval(timer);
      timer = undefined;
    },
  };
}
