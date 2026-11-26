import type { ContextMessage } from '../../conversation/application/message-store.js';
import type { MemoryChange, SavedFact } from '../domain/memory.js';

export interface MemoryExtractor {
  extract(input: { transcript: ContextMessage[]; existing: SavedFact[] }): Promise<MemoryChange[]>;
}
