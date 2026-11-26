import { isMemoryCategory } from './categories.js';
import { isSensitive, sameFact } from './sensitive.js';
import type { MemoryChange, SavedFact } from './memory.js';

const MAX_CHANGES = 10;
const MAX_FACT_LENGTH = 500;

interface ProposedFact {
  id?: string | null | undefined;
  fact: string;
  category?: string | undefined;
}

export function acceptChanges(proposals: ProposedFact[], existing: SavedFact[]): MemoryChange[] {
  const known = new Map(existing.map((memory) => [memory.id, memory]));
  const changes: MemoryChange[] = [];
  for (const item of proposals) {
    const fact = item.fact.trim();
    if (fact.length === 0 || fact.length > MAX_FACT_LENGTH || isSensitive(fact)) continue;

    const target = item.id ? known.get(item.id) : undefined;
    const unchanged = target
      ? sameFact(target.fact, fact)
      : existing.some((memory) => sameFact(memory.fact, fact));
    const repeated = changes.some((change) => sameFact(change.fact, fact));
    if (unchanged || repeated) continue;

    changes.push({
      id: target?.id ?? null,
      fact,
      category: isMemoryCategory(item.category) ? item.category : 'other',
    });
    if (changes.length === MAX_CHANGES) break;
  }
  return changes;
}
