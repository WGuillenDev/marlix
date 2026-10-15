import { buildSystemPrompt, type ChatMode } from '../config/system-prompt.js';
import type { ActivationLog } from './crisis/activation-log.js';
import type { CrisisFilter } from './crisis/filter.js';
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
}

export type ChatOutcome = { type: 'reply'; content: string } | { type: 'crisis' };

export interface ChatService {
  /**
   * Returns marlix's reply to one message, or a crisis. Fails with an
   * LlmError or a UsageLimitExceededError.
   */
  reply(input: ChatInput): Promise<ChatOutcome>;
}

/**
 * The crisis filter runs first, on every message and in both modes; a crisis
 * never reaches the model and is answered even at the daily cap, without
 * counting. Then the usage limits apply. The personality system prompt goes
 * first on every call, the reply is reviewed before it is returned, and only
 * a successful reply counts. There is no history or memory yet (Sprint 4), so
 * the model only sees the current message.
 */
export function createChatService(
  llm: LlmProvider,
  crisisFilter: CrisisFilter,
  activationLog: ActivationLog,
  usageLimiter: UsageLimiter,
): ChatService {
  return {
    async reply({ message, mode, user }) {
      const decision = await crisisFilter.check(message);
      if (decision.crisis) {
        const { signal, layer } = decision;
        activationLog.record({ at: new Date().toISOString(), signal, layer });
        return { type: 'crisis' };
      }

      usageLimiter.reserveAttempt(user);

      const completion = await llm.complete({
        messages: [
          { role: 'system', content: buildSystemPrompt(mode, []) },
          { role: 'user', content: message },
        ],
        maxOutputTokens: MAX_OUTPUT_TOKENS[mode],
      });
      const review = reviewReply(completion.content);
      // Only the rule is logged, never the reply.
      if (review.replacedBy) console.warn(`Reply replaced by the review: ${review.replacedBy}`);
      usageLimiter.recordInteraction(user);
      return { type: 'reply', content: review.content };
    },
  };
}
