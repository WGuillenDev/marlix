import { buildSystemPrompt, type ChatMode } from '../config/system-prompt.js';
import type { LlmProvider } from './llm/index.js';

// Upper bound for one reply, reasoning included. Voice replies are one to
// three short sentences, so they need less room.
const MAX_OUTPUT_TOKENS: Record<ChatMode, number> = { text: 1024, voice: 512 };

export interface ChatInput {
  message: string;
  mode: ChatMode;
}

export interface ChatService {
  /** Returns marlix's reply to one message. Fails with an LlmError. */
  reply(input: ChatInput): Promise<string>;
}

/**
 * Builds the conversation for the model and asks for the reply. The
 * personality system prompt goes first on every call. There is no history
 * or memory yet (Sprint 4), so the model only sees the current message.
 */
export function createChatService(llm: LlmProvider): ChatService {
  return {
    async reply({ message, mode }) {
      const completion = await llm.complete({
        messages: [
          { role: 'system', content: buildSystemPrompt(mode, []) },
          { role: 'user', content: message },
        ],
        maxOutputTokens: MAX_OUTPUT_TOKENS[mode],
      });
      return completion.content;
    },
  };
}
