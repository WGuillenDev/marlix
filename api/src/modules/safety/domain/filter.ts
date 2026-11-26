// Check clear risk locally before any model can see the message.
import { compilePhrasePattern, normalizeForMatching } from '../../../shared/domain/normalize.js';
import {
  AMBIGUOUS_SIGNALS,
  FIGURATIVE_DEATH_CAUSES,
  FIGURATIVE_DEATH_WORDS,
  RISK_SIGNALS,
} from './signals.js';

export type CrisisLevel = 'risk' | 'ambiguous' | 'normal';

const RISK_PATTERN = compilePhrasePattern(RISK_SIGNALS);
const AMBIGUOUS_PATTERN = compilePhrasePattern(AMBIGUOUS_SIGNALS);
const FIGURATIVE_PATTERN = new RegExp(
  `(?:^| )(?:${FIGURATIVE_DEATH_WORDS.map(normalizeForMatching).join('|')}) de (?:la )?` +
    `(?:${FIGURATIVE_DEATH_CAUSES.map(normalizeForMatching).join('|')})(?= |$)`,
  'g',
);

export function detectCrisisSignal(message: string): CrisisLevel {
  const text = normalizeForMatching(message).replace(FIGURATIVE_PATTERN, ' ');
  if (RISK_PATTERN.test(text)) return 'risk';
  if (AMBIGUOUS_PATTERN.test(text)) return 'ambiguous';
  return 'normal';
}
