import { detectCrisisSignal, type CrisisLevel } from '../domain/filter.js';

export type AmbiguousResolver = (message: string) => Promise<boolean>;

export type CrisisLayer =
  | 'keywords'
  | 'classifier'
  | 'classifier_failure'
  | 'no_classifier';

export type CrisisDecision =
  | { crisis: false }
  | { crisis: true; signal: Exclude<CrisisLevel, 'normal'>; layer: CrisisLayer };

export interface CrisisFilter {
  check(message: string): Promise<CrisisDecision>;
}

/** If isolated classification is unavailable or fails, treat ambiguity as risk. */
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
