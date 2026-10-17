import { randomUUID } from 'node:crypto';

import { buildSystemPrompt, type ChatMode } from '../config/system-prompt.js';
import type { ActivationLog } from './crisis/activation-log.js';
import type { CrisisFilter } from './crisis/filter.js';
import { MessageNotFoundError, type MessageStore, type SavedTurn } from './history/message-store.js';
import type { LlmProvider } from './llm/index.js';
import { reviewReply } from './review/reply-review.js';
import type { UsageLimiter, UsageUser } from './usage/usage-limiter.js';

// Upper bound for one reply, reasoning included. Voice replies are one to
// three short sentences, so they need less room.
const MAX_OUTPUT_TOKENS: Record<ChatMode, number> = { text: 1024, voice: 512 };

export interface ChatInput {
  message: string;
  mode: ChatMode;
  user: UsageUser;
  /** The reply of marlix the user cut off by talking (US-12). */
  interruptedMessageId?: string | null | undefined;
}

/** What was said in this turn, with the ids the history gave it. */
export type ChatOutcome = SavedTurn & { type: 'reply' | 'crisis' };

export interface ChatService {
  /**
   * Returns marlix's reply to one message, or a crisis, already saved in the
   * history. Fails with an LlmError, a UsageLimitExceededError, a
   * MessageNotFoundError or a HistoryStoreError.
   */
  reply(input: ChatInput): Promise<ChatOutcome>;
}

/**
 * The crisis filter runs first, on every message and in both modes; a crisis
 * never reaches the model and is answered even at the daily cap, without
 * counting. Then the usage limits apply. The personality system prompt goes
 * first on every call, the reply is reviewed before it is returned, and only
 * a successful reply counts. Every turn is saved in the history (S4-4); the
 * model sees the last messages of the conversation (S4-5), never the ones of
 * a crisis, and what it remembers about the person (S4-7).
 */
export function createChatService(
  llm: LlmProvider,
  crisisFilter: CrisisFilter,
  activationLog: ActivationLog,
  usageLimiter: UsageLimiter,
  messages: MessageStore,
  crisisReply: string,
  contextMessages: number,
  endIdleConversation: (userId: string) => Promise<void>,
  promptMemories: (userId: string) => Promise<string[]>,
): ChatService {
  return {
    async reply({ message, mode, user, interruptedMessageId }) {
      const messageAt = new Date();
      // First, so a message that comes after a long silence starts a new
      // conversation, with its own window, and the old one gets its memory.
      await endIdleConversation(user.id).catch(() => undefined);
      const decision = await crisisFilter.check(message);
      if (decision.crisis) {
        const { signal, layer } = decision;
        activationLog.record({ at: new Date().toISOString(), signal, layer });
        // The help never waits on the database: if saving fails, the person
        // still gets the 9-1-1 reply, only without it in their history.
        const turn = await messages
          .saveTurn(user.id, { message, reply: crisisReply, messageAt, crisis: true })
          .catch(() => unsavedTurn(message, crisisReply, messageAt));
        return { type: 'crisis', ...turn };
      }

      if (interruptedMessageId) {
        if (!(await messages.markInterrupted(user.id, interruptedMessageId))) {
          throw new MessageNotFoundError();
        }
      }
      usageLimiter.reserveAttempt(user);

      // Before this turn is saved, so the new message is not in it twice.
      const [recent, facts] = await Promise.all([
        messages.recent(user.id, contextMessages),
        promptMemories(user.id),
      ]);

      const completion = await llm.complete({
        messages: [
          { role: 'system', content: buildSystemPrompt(mode, facts) },
          ...recent,
          { role: 'user', content: message },
        ],
        maxOutputTokens: MAX_OUTPUT_TOKENS[mode],
      });
      const review = reviewReply(completion.content);
      // Only the rule is logged, never the reply.
      if (review.replacedBy) console.warn(`Reply replaced by the review: ${review.replacedBy}`);
      // A reply that cannot be saved is not delivered or counted: the history
      // would miss a message the person has seen.
      const turn = await messages.saveTurn(user.id, {
        message,
        reply: review.content,
        messageAt,
        crisis: false,
      });
      usageLimiter.recordInteraction(user);
      return { type: 'reply', ...turn };
    },
  };
}

function unsavedTurn(message: string, reply: string, messageAt: Date): SavedTurn {
  const replyAt = new Date(Math.max(Date.now(), messageAt.getTime() + 1));
  return {
    userMessage: {
      id: randomUUID(),
      role: 'user',
      content: message,
      createdAt: messageAt.toISOString(),
      interrupted: false,
    },
    reply: {
      id: randomUUID(),
      role: 'assistant',
      content: reply,
      createdAt: replyAt.toISOString(),
      interrupted: false,
    },
  };
}
