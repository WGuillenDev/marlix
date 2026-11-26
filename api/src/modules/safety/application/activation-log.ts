import type { CrisisLevel } from '../domain/filter.js';
import type { CrisisLayer } from '../application/crisis-filter.js';

export interface CrisisActivation {
  at: string;
  signal: Exclude<CrisisLevel, 'normal'>;
  layer: CrisisLayer;
}

export interface ActivationLog {
  record(activation: CrisisActivation): void;
}
