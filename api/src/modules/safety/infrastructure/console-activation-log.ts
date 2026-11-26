import type { ActivationLog } from '../application/activation-log.js';

export function createConsoleActivationLog(): ActivationLog {
  return {
    record({ at, signal, layer }) {
      console.info(JSON.stringify({ event: 'crisis_activation', at, signal, layer }));
    },
  };
}
