import { compilePhrasePattern, normalizeForMatching } from '../../../shared/domain/normalize.js';
import { REVIEW_RULES, type ReviewRule } from './rules.js';

export const SAFE_REPLY =
  'Perdón, no te puedo responder bien a eso. ' +
  'Contame un poco más de cómo te sentís, que aquí estoy para escucharte.';

const RULE_PATTERNS = (Object.entries(REVIEW_RULES) as [ReviewRule, readonly string[]][]).map(
  ([rule, phrases]) => [rule, compilePhrasePattern(phrases, { ignoreNegated: true })] as const,
);

export type SentenceReview = { ok: true } | { ok: false; rule: ReviewRule };

/** Review one sentence at a time for both text replies and voice streams. */
export function reviewSentence(sentence: string): SentenceReview {
  const text = normalizeForMatching(sentence);
  for (const [rule, pattern] of RULE_PATTERNS) {
    if (pattern.test(text)) return { ok: false, rule };
  }
  return { ok: true };
}

export function splitIntoSentences(text: string): string[] {
  return text
    .split(/(?<=[.!?…])\s+|\n+/)
    .map((sentence) => sentence.trim())
    .filter((sentence) => sentence.length > 0);
}

export type ReplyReview = { content: string; replacedBy?: ReviewRule };

export function reviewReply(reply: string): ReplyReview {
  for (const sentence of splitIntoSentences(reply)) {
    const review = reviewSentence(sentence);
    if (!review.ok) return { content: SAFE_REPLY, replacedBy: review.rule };
  }
  return { content: reply };
}
