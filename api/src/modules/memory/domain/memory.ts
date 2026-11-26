import type { MemoryCategory } from './categories.js';

export interface Memory {
  id: string;
  fact: string;
  category: string | null;
  createdAt: string;
  updatedAt: string;
}

/** A fact to save: `id` is the memory it rewrites, or null if it is new. */
export interface MemoryChange {
  id: string | null;
  fact: string;
  category: MemoryCategory;
}

export type SavedFact = Pick<Memory, 'id' | 'fact'>;
