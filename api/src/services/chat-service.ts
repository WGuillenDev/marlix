import { randomUUID } from 'node:crypto';

import { buildSystemPrompt, type ChatMode } from '../config/system-prompt.js';
import type { ActivationLog } from './crisis/activation-log.js';
import type { CrisisFilter } from './crisis/filter.js';
import { MessageNotFoundError, type MessageStore, type SavedTurn } from './history/message-store.js';
import { LlmError, type LlmMessage, type LlmProvider } from './llm/index.js';
import { reviewReply, reviewSentence, SAFE_REPLY } from './review/reply-review.js';
import { SentenceStream } from './speech/sentence-stream.js';
import { toSpokenText } from './speech/spoken-text.js';
import { detectTone, type MessageTone } from './tone/message-tone.js';
import type { UsageLimiter, UsageSnapshot, UsageUser } from './usage/usage-limiter.js';

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

/**
 * What was said in this turn, with the ids the history gave it. `usage` is
 * missing when the database could not be read after the reply: the person
 * still gets it, and the app keeps the last usage it knew. `tone` is what the
 * avatar reacts to (S5-4); a crisis is always neutral.
 */
export type ChatOutcome = SavedTurn & {
  type: 'reply' | 'crisis';
  tone: MessageTone;
  usage?: UsageSnapshot | undefined;
};

/** One sentence of a streamed reply, already cleaned and reviewed. */
export interface StreamedSentence {
  index: number;
  text: string;
}

export interface ChatService {
  /**
   * Returns marlix's reply to one message, or a crisis, already saved in the
   * history. Fails with an LlmError, a UsageLimitExceededError, a
   * MessageNotFoundError, a HistoryStoreError or a UsageStoreError.
   */
  reply(input: ChatInput): Promise<ChatOutcome>;
  /**
   * Same turn as `reply`, but each sentence goes to `onSentence` as soon as
   * it is complete and has passed the review (S6-10). Nothing is called for a
   * crisis. If a sentence fails the review, the safe reply is sent after the
   * ones already approved and the rest of the model's reply is dropped. The
   * outcome is the full saved reply. Fails like `reply`; once a sentence was
   * delivered, a failure leaves the turn unsaved and uncounted.
   */
  replyStream(
    input: ChatInput,
    onSentence: (sentence: StreamedSentence) => void,
    signal?: AbortSignal,
  ): Promise<ChatOutcome>;
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
  type Prepared =
    | { outcome: ChatOutcome }
    | { messages: LlmMessage[]; messageAt: Date; message: string; mode: ChatMode };

  /** Everything before the model: the crisis filter, the limits and the context. */
  async function prepare({
    message,
    mode,
    user,
    interruptedMessageId,
  }: ChatInput): Promise<Prepared> {
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
      // Not counted, and not worth failing the help over: usage is optional.
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

  /** A reply that cannot be saved is not delivered or counted: the history would miss a message the person has seen. */
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
      // In voice mode the reply is read aloud, so it is cleaned first: the review,
      // the history and the memory then all see exactly what is said (S6-3).
      const spoken = input.mode === 'voice' ? toSpokenText(completion.content) : completion.content;
      // Nothing left to say (only emojis, for example): the safe reply, never an empty one.
      const review: { content: string; replacedBy?: string } =
        spoken === '' ? { content: SAFE_REPLY, replacedBy: 'nothing to say' } : reviewReply(spoken);
      // Only the rule is logged, never the reply.
      if (review.replacedBy) console.warn(`Reply replaced by the review: ${review.replacedBy}`);
      return finish(input.user, prepared, review.content);
    },

    async replyStream(input, onSentence, signal) {
      const prepared = await prepare(input);
      if ('outcome' in prepared) return prepared.outcome;

      const spoken: string[] = [];
      let failedRule: string | undefined;
      // Cleans and reviews one sentence; false once the reply must stop.
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
