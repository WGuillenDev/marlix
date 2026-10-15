// Review of the model's reply before it reaches the person (S2-4). Rules in
// code, no second model call: a few regular expressions per sentence.
import { compilePhrasePattern, normalizeForMatching } from '../crisis/normalize.js';
import { REVIEW_RULES, type ReviewRule } from './rules.js';

/** Replaces a reply that failed the review. It gives no advice and keeps the conversation going. */
export const SAFE_REPLY =
  'Perdón, no te puedo responder bien a eso. ' +
  'Contame un poco más de cómo te sentís, que aquí estoy para escucharte.';

const RULE_PATTERNS = (Object.entries(REVIEW_RULES) as [ReviewRule, readonly string[]][]).map(
  ([rule, phrases]) => [rule, compilePhrasePattern(phrases, { ignoreNegated: true })] as const,
);

export type SentenceReview = { ok: true } | { ok: false; rule: ReviewRule };

/**
 * Reviews one sentence. The unit is the sentence so the same check serves
 * the full text reply and the voice reply sent sentence by sentence (S6-10).
 */
export function reviewSentence(sentence: string): SentenceReview {
  const text = normalizeForMatching(sentence);
  for (const [rule, pattern] of RULE_PATTERNS) {
    if (pattern.test(text)) return { ok: false, rule };
  }
  return { ok: true };
}

/** Splits a reply into sentences, keeping their punctuation. */
export function splitIntoSentences(text: string): string[] {
  return text
    .split(/(?<=[.!?…])\s+|\n+/)
    .map((sentence) => sentence.trim())
    .filter((sentence) => sentence.length > 0);
}

export type ReplyReview = { content: string; replacedBy?: ReviewRule };

/** Reviews a full reply: if any sentence fails, the whole reply is replaced. */
export function reviewReply(reply: string): ReplyReview {
  for (const sentence of splitIntoSentences(reply)) {
    const review = reviewSentence(sentence);
    if (!review.ok) return { content: SAFE_REPLY, replacedBy: review.rule };
  }
  return { content: reply };
}
