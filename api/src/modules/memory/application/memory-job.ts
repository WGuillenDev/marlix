import type {
  ConversationStore,
  PendingConversation,
} from '../../conversation/application/conversation-store.js';
import { LlmError } from '../../../shared/application/ai/errors.js';

import type { MemoryExtractor } from './memory-extractor.js';
import type { MemoryStore } from './memory-store.js';

// Bound saved facts because every selected memory adds to the prompt's token cost.
export const MAX_MEMORIES_PER_USER = 50;

const DEFAULT_SWEEP_EVERY_MS = 5 * 60_000;
// Serialize extraction to limit contention with live chat for the Groq quota.
const DEFAULT_SPACING_MS = 3000;
const DEFAULT_MAX_ATTEMPTS = 3;

export interface MemoryJobOptions {
  conversations: ConversationStore;
  memories: MemoryStore;
  extractor: MemoryExtractor;
  idleSeconds: number;
  sweepEveryMs?: number;
  spacingMs?: number;
  /** Per conversation and per process: a restart tries again. */
  maxAttempts?: number;
}

export interface MemoryJob {
  /** Wait for the database update only. Extraction runs in the background. */
  endIdleConversation(userId: string): Promise<void>;
  sweep(): Promise<void>;
  /** The periodic sweep does not keep the process alive. */
  start(): void;
  stop(): void;
  whenIdle(): Promise<void>;
}

export function createMemoryJob({
  conversations,
  memories,
  extractor,
  idleSeconds,
  sweepEveryMs = DEFAULT_SWEEP_EVERY_MS,
  spacingMs = DEFAULT_SPACING_MS,
  maxAttempts = DEFAULT_MAX_ATTEMPTS,
}: MemoryJobOptions): MemoryJob {
  const queue: PendingConversation[] = [];
  const queued = new Set<string>();
  const attempts = new Map<string, number>();
  let running: Promise<void> | undefined;
  let scheduling: Promise<void> = Promise.resolve();
  let timer: NodeJS.Timeout | undefined;

  function enqueue(pending: PendingConversation[]): void {
    for (const conversation of pending) {
      if (queued.has(conversation.id) || (attempts.get(conversation.id) ?? 0) >= maxAttempts) {
        continue;
      }
      queued.add(conversation.id);
      queue.push(conversation);
    }
  }

  async function extractFrom({ id, userId }: PendingConversation): Promise<void> {
    const transcript = await conversations.transcript(id, userId);
    if (!transcript.some((message) => message.role === 'user')) {
      await conversations.markExtracted(id, userId);
      return;
    }

    const existing = await memories.list(userId);
    const changes = await extractor.extract({ transcript, existing });

    let added = 0;
    let updated = 0;
    let total = existing.length;
    for (const change of changes) {
      if (change.id) {
        const { fact, category } = change;
        if (await memories.update(userId, change.id, { fact, category })) updated += 1;
      } else if (total < MAX_MEMORIES_PER_USER) {
        await memories.add(userId, {
          fact: change.fact,
          category: change.category,
          sourceConversationId: id,
        });
        added += 1;
        total += 1;
      }
    }
    await conversations.markExtracted(id, userId);
    console.log(`Memory extracted: ${added} added, ${updated} updated`);
  }

  async function run(): Promise<void> {
    while (queue.length > 0) {
      const conversation = queue.shift()!;
      try {
        await extractFrom(conversation);
        attempts.delete(conversation.id);
      } catch (error) {
        const tries = (attempts.get(conversation.id) ?? 0) + 1;
        attempts.set(conversation.id, tries);
        const kind = error instanceof LlmError ? `LLM ${error.kind}` : (error as Error).name;
        const outcome = tries >= maxAttempts ? 'giving up until the next restart' : 'will retry';
        console.warn(`Memory extraction failed (${kind}), ${outcome}`);
      } finally {
        queued.delete(conversation.id);
      }
      if (queue.length > 0) await new Promise((resolve) => setTimeout(resolve, spacingMs));
    }
  }

  function drain(): Promise<void> {
    running ??= run().finally(() => {
      running = undefined;
    });
    return running;
  }

  async function queuePending(): Promise<void> {
    enqueue(await conversations.listPending());
    await drain();
  }

  async function sweep(): Promise<void> {
    try {
      await conversations.closeIdle(idleSeconds);
      await queuePending();
    } catch (error) {
      console.warn(`Memory sweep failed (${(error as Error).name})`);
    }
  }

  return {
    async endIdleConversation(userId) {
      try {
        if ((await conversations.closeIdle(idleSeconds, userId)) === 0) return;
      } catch {
        return;
      }
      scheduling = scheduling.then(() =>
        queuePending().catch((error) =>
          console.warn(`Memory extraction not queued (${(error as Error).name})`),
        ),
      );
    },

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

    async whenIdle() {
      await scheduling;
      await running;
    },
  };
}
