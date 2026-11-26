import type { Memory } from './memory.js';

/** Prefer recent memories, then order them consistently to preserve the prompt cache. */
export function selectForPrompt(memories: Memory[], limit: number): string[] {
  return memories
    .toSorted((a, b) => b.updatedAt.localeCompare(a.updatedAt) || b.id.localeCompare(a.id))
    .slice(0, limit)
    .toSorted((a, b) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id))
    .map(({ fact }) => oneLine(fact));
}

// Strip line breaks so a fact cannot add a new instruction block.
function oneLine(fact: string): string {
  return fact.replace(/\s+/g, ' ').trim();
}
