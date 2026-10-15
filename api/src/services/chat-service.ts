import { buildSystemPrompt, type ChatMode } from '../config/system-prompt.js';
import type { CrisisFilter } from './crisis/filter.js';
import type { LlmProvider } from './llm/index.js';
import { reviewReply } from './review/reply-review.js';

// Upper bound for one reply, reasoning included. Voice replies are one to
// three short sentences, so they need less room.
const MAX_OUTPUT_TOKENS: Record<ChatMode, number> = { text: 1024, voice: 512 };

export interface ChatInput {
  message: string;
  mode: ChatMode;
}

export type ChatOutcome = { type: 'reply'; content: string } | { type: 'crisis' };

export interface ChatService {
  /** Returns marlix's reply to one message, or a crisis. Fails with an LlmError. */
  reply(input: ChatInput): Promise<ChatOutcome>;
}

/**
 * The crisis filter runs first, on every message and in both modes; a crisis
 * never reaches the model. Otherwise the personality system prompt goes first
 * on every call, and the reply is reviewed before it is returned. There is no
 * history or memory yet (Sprint 4), so the model only sees the current message.
 */
export function createChatService(llm: LlmProvider, crisisFilter: CrisisFilter): ChatService {
  return {
    async reply({ message, mode }) {
      if (await crisisFilter.isCrisis(message)) return { type: 'crisis' };

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
      return { type: 'reply', content: review.content };
    },
  };
}
