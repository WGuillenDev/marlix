import { randomUUID } from 'node:crypto';

import { buildSystemPrompt, type ChatMode } from './system-prompt.js';
import type { ActivationLog } from '../../safety/application/activation-log.js';
import type { CrisisFilter } from '../../safety/application/crisis-filter.js';
import { MessageNotFoundError, type MessageStore, type SavedTurn } from './message-store.js';
import { LlmError } from '../../../shared/application/ai/errors.js';
import type { LlmMessage, LlmProvider } from '../../../shared/application/ai/types.js';
import { reviewReply, reviewSentence, SAFE_REPLY } from '../../safety/domain/reply-review.js';
import { SentenceStream } from '../domain/sentence-stream.js';
import { toSpokenText } from '../domain/spoken-text.js';
import { detectTone, type MessageTone } from '../domain/message-tone.js';
import type { UsageLimiter, UsageSnapshot, UsageUser } from '../../usage/application/usage-limiter.js';

// Voice prompts request shorter replies, so they get a smaller token budget.
const MAX_OUTPUT_TOKENS: Record<ChatMode, number> = { text: 1024, voice: 512 };

export interface ChatInput {
  message: string;
  mode: ChatMode;
  user: UsageUser;
  interruptedMessageId?: string | null | undefined;
}

/** Usage may be absent if the counter could not be read after saving the turn. */
export type ChatOutcome = SavedTurn & {
  type: 'reply' | 'crisis';
  tone: MessageTone;
  usage?: UsageSnapshot | undefined;
};

export interface StreamedSentence {
  index: number;
  text: string;
}

export interface ChatService {
  /** Saves the completed turn before returning the reply. */
  reply(input: ChatInput): Promise<ChatOutcome>;
  /** Emits reviewed sentences as they arrive. Crisis replies are returned as a complete response. */
  replyStream(
    input: ChatInput,
    onSentence: (sentence: StreamedSentence) => void,
    signal?: AbortSignal,
  ): Promise<ChatOutcome>;
}

interface ChatDependencies {
  llm: LlmProvider;
  crisisFilter: CrisisFilter;
  activationLog: ActivationLog;
  usageLimiter: UsageLimiter;
  messages: MessageStore;
  crisisReply: string;
  contextMessages: number;
  endIdleConversation: (userId: string) => Promise<void>;
  promptMemories: (userId: string) => Promise<string[]>;
}

/** Crisis handling applies to both modes, even when the daily cap is exhausted. */
export function createChatService({
  llm,
  crisisFilter,
  activationLog,
  usageLimiter,
  messages,
  crisisReply,
  contextMessages,
  endIdleConversation,
  promptMemories,
}: ChatDependencies): ChatService {
  type Prepared =
    | { outcome: ChatOutcome }
    | { messages: LlmMessage[]; messageAt: Date; message: string; mode: ChatMode };

  async function prepare({
    message,
    mode,
    user,
    interruptedMessageId,
  }: ChatInput): Promise<Prepared> {
    const messageAt = new Date();
    // Close idle sessions first so a new turn gets a fresh conversation and context.
    await endIdleConversation(user.id).catch(() => undefined);
    const decision = await crisisFilter.check(message);
    if (decision.crisis) {
      const { signal, layer } = decision;
      activationLog.record({ at: new Date().toISOString(), signal, layer });
      // A history write failure must not prevent a crisis reply from reaching the user.
      const turn = await messages
        .saveTurn(user.id, { message, reply: crisisReply, messageAt, crisis: true })
        .catch(() => unsavedTurn(message, crisisReply, messageAt));
      const usage = await usageLimiter.snapshot(user).catch(() => undefined);
      return { outcome: { type: 'crisis', tone: 'neutral', ...turn, usage } };
    }

    if (interruptedMessageId) {
      if (!(await messages.markInterrupted(user.id, interruptedMessageId))) {
        throw new MessageNotFoundError();
      }
    }
    await usageLimiter.reserveAttempt(user);

    // Before this turn is saved, so the new message is not in it twice.
    const [recent, facts] = await Promise.all([
      messages.recent(user.id, contextMessages),
      promptMemories(user.id),
    ]);

    return {
      messageAt,
      message,
      mode,
      messages: [
        { role: 'system', content: buildSystemPrompt(mode, facts) },
        ...recent,
        { role: 'user', content: message },
      ],
    };
  }

  /** If saving fails, do not deliver or count a reply missing from history. */
  async function finish(
    user: UsageUser,
    { message, messageAt }: { message: string; messageAt: Date },
    reply: string,
  ): Promise<ChatOutcome> {
    const turn = await messages.saveTurn(user.id, { message, reply, messageAt, crisis: false });
    const usage = await usageLimiter.recordInteraction(user);
    return { type: 'reply', tone: detectTone(message), ...turn, usage };
  }

  return {
    async reply(input) {
      const prepared = await prepare(input);
      if ('outcome' in prepared) return prepared.outcome;

      const completion = await llm.complete({
        messages: prepared.messages,
        maxOutputTokens: MAX_OUTPUT_TOKENS[input.mode],
      });
      // Clean text first so review, playback and stored history see the same reply.
      const spoken = input.mode === 'voice' ? toSpokenText(completion.content) : completion.content;
      // Nothing left to say (only emojis, for example): the safe reply, never an empty one.
      const review: { content: string; replacedBy?: string } =
        spoken === '' ? { content: SAFE_REPLY, replacedBy: 'nothing to say' } : reviewReply(spoken);
      if (review.replacedBy) console.warn(`Reply replaced by the review: ${review.replacedBy}`);
      return finish(input.user, prepared, review.content);
    },

    async replyStream(input, onSentence, signal) {
      const prepared = await prepare(input);
      if ('outcome' in prepared) return prepared.outcome;

      const spoken: string[] = [];
      let failedRule: string | undefined;
      const say = (raw: string): boolean => {
        const text = input.mode === 'voice' ? toSpokenText(raw) : raw;
        if (text === '') return true;
        const review = reviewSentence(text);
        if (!review.ok) {
          failedRule = review.rule;
          return false;
        }
        onSentence({ index: spoken.length, text });
        spoken.push(text);
        return true;
      };

      const sentences = new SentenceStream();
      let received = false;
      generation: {
        for await (const piece of llm.stream({
          messages: prepared.messages,
          maxOutputTokens: MAX_OUTPUT_TOKENS[input.mode],
          ...(signal ? { signal } : {}),
        })) {
          received = true;
          for (const sentence of sentences.push(piece)) {
            if (!say(sentence)) break generation;
          }
        }
        for (const sentence of sentences.flush()) {
          if (!say(sentence)) break generation;
        }
      }
      if (!received) throw new LlmError('empty_response', 'The model returned no text');

      if (failedRule || spoken.length === 0) {
        console.warn(`Reply replaced by the review: ${failedRule ?? 'nothing to say'}`);
        onSentence({ index: spoken.length, text: SAFE_REPLY });
        spoken.push(SAFE_REPLY);
      }
      return finish(input.user, prepared, spoken.join(' '));
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
