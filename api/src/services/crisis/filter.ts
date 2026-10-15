// Crisis filter (S2-1). It runs in code, before any call to the model,
// because a model can be wrong or manipulated and a rule in code cannot.
// Protocol: docs/crisis-protocol.md.
import { normalizeForMatching } from './normalize.js';
import {
  AMBIGUOUS_SIGNALS,
  FIGURATIVE_DEATH_CAUSES,
  FIGURATIVE_DEATH_WORDS,
  RISK_SIGNALS,
} from './signals.js';

export type CrisisLevel = 'risk' | 'ambiguous' | 'normal';

/** Decides an ambiguous message: true means crisis. Provided by S2-2. */
export type AmbiguousResolver = (message: string) => Promise<boolean>;

export interface CrisisFilter {
  isCrisis(message: string): Promise<boolean>;
}

function compileSignals(signals: readonly string[]): RegExp {
  const alternatives = signals.map((signal) => {
    const isPrefix = signal.endsWith('*');
    const phrase = normalizeForMatching(isPrefix ? signal.slice(0, -1) : signal);
    return isPrefix ? `${phrase}[a-z]*` : phrase;
  });
  return new RegExp(`(?:^| )(?:${alternatives.join('|')})(?: |$)`);
}

const RISK_PATTERN = compileSignals(RISK_SIGNALS);
const AMBIGUOUS_PATTERN = compileSignals(AMBIGUOUS_SIGNALS);
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
    async isCrisis(message) {
      const level = detectCrisisSignal(message);
      if (level === 'risk') return true;
      if (level === 'normal') return false;
      if (!resolveAmbiguous) return true;

      try {
        return await resolveAmbiguous(message);
      } catch {
        return true;
      }
    },
  };
}
