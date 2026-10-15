// Crisis filter (S2-1). It runs in code, before any call to the model,
// because a model can be wrong or manipulated and a rule in code cannot.
// Protocol: docs/crisis-protocol.md.
import { compilePhrasePattern, normalizeForMatching } from './normalize.js';
import {
  AMBIGUOUS_SIGNALS,
  FIGURATIVE_DEATH_CAUSES,
  FIGURATIVE_DEATH_WORDS,
  RISK_SIGNALS,
} from './signals.js';

export type CrisisLevel = 'risk' | 'ambiguous' | 'normal';

/** Decides an ambiguous message: true means crisis. Provided by S2-2. */
export type AmbiguousResolver = (message: string) => Promise<boolean>;

/** Which part of the protocol decided the crisis (logged by S2-5). */
export type CrisisLayer =
  /** A clear risk signal. */
  | 'keywords'
  /** The second layer classified an ambiguous message as risk. */
  | 'classifier'
  /** The second layer failed or timed out: the conservative criterion applied. */
  | 'classifier_failure'
  /** Ambiguous, with no second layer configured. */
  | 'no_classifier';

export type CrisisDecision =
  | { crisis: false }
  | { crisis: true; signal: Exclude<CrisisLevel, 'normal'>; layer: CrisisLayer };

export interface CrisisFilter {
  check(message: string): Promise<CrisisDecision>;
}

const RISK_PATTERN = compilePhrasePattern(RISK_SIGNALS);
const AMBIGUOUS_PATTERN = compilePhrasePattern(AMBIGUOUS_SIGNALS);
const FIGURATIVE_PATTERN = new RegExp(
  `(?:^| )(?:${FIGURATIVE_DEATH_WORDS.map(normalizeForMatching).join('|')}) de (?:la )?` +
    `(?:${FIGURATIVE_DEATH_CAUSES.map(normalizeForMatching).join('|')})(?= |$)`,
  'g',
);

/** Classifies one message by its signals alone, without calling anything. */
export function detectCrisisSignal(message: string): CrisisLevel {
  const text = normalizeForMatching(message).replace(FIGURATIVE_PATTERN, ' ');
  if (RISK_PATTERN.test(text)) return 'risk';
  if (AMBIGUOUS_PATTERN.test(text)) return 'ambiguous';
  return 'normal';
}

/**
 * An ambiguous message is decided by `resolveAmbiguous` (the second layer,
 * S2-2). Without it, or when it fails, the message is treated as a crisis:
 * a false alarm is better than leaving someone without help.
 */
export function createCrisisFilter(resolveAmbiguous?: AmbiguousResolver): CrisisFilter {
  return {
    async check(message) {
      const level = detectCrisisSignal(message);
      if (level === 'normal') return { crisis: false };
      if (level === 'risk') return { crisis: true, signal: 'risk', layer: 'keywords' };
      if (!resolveAmbiguous) return { crisis: true, signal: 'ambiguous', layer: 'no_classifier' };

      try {
        if (!(await resolveAmbiguous(message))) return { crisis: false };
        return { crisis: true, signal: 'ambiguous', layer: 'classifier' };
      } catch {
        return { crisis: true, signal: 'ambiguous', layer: 'classifier_failure' };
      }
    },
  };
}
