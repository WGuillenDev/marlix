// Which memories go into the system prompt (S4-7). Rules and reasons: docs/memory.md.
import type { Memory } from './memory-store.js';

/**
 * The facts for one call, as single lines of text.
 *
 * When there are more than `limit`, the ones updated most recently win: they
 * are what is still going on in the person's life, and a fact that was just
 * corrected or mentioned again is more likely to matter than one told months
 * ago. Choosing by meaning is left to a later version.
 *
 * The chosen facts always come in the same order (oldest first), so the text
 * is identical from one message to the next until the memory changes, which
 * is what lets the model's cache reuse the prompt.
 */
export function selectForPrompt(memories: Memory[], limit: number): string[] {
  return memories
    .toSorted((a, b) => b.updatedAt.localeCompare(a.updatedAt) || b.id.localeCompare(a.id))
    .slice(0, limit)
    .toSorted((a, b) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id))
    .map(({ fact }) => oneLine(fact));
}

// A fact is a line of a list. Without line breaks it cannot add a heading or a
// new paragraph that would read as an instruction.
function oneLine(fact: string): string {
  return fact.replace(/\s+/g, ' ').trim();
}
