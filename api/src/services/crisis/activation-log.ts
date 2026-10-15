// Record of crisis filter activations (S2-5), to tune the filter: too many
// suggest false alarms, none that it may not be detecting. It never holds
// the message in any form: not the text, a hash or its length.
import type { CrisisLayer, CrisisLevel } from './filter.js';

export interface CrisisActivation {
  /** ISO 8601, UTC. */
  at: string;
  signal: Exclude<CrisisLevel, 'normal'>;
  layer: CrisisLayer;
}

export interface ActivationLog {
  record(activation: CrisisActivation): void;
}

/**
 * Writes each activation as one JSON line to the logs, where it can be
 * searched and counted per period. The backend has no database until S4-1;
 * a database implementation of ActivationLog can replace this one then.
 */
export function createConsoleActivationLog(): ActivationLog {
  return {
    record({ at, signal, layer }) {
      console.info(JSON.stringify({ event: 'crisis_activation', at, signal, layer }));
    },
  };
}
