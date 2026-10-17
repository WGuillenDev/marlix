// Closed list, so the "what marlix knows about me" screen (S4-8) can group
// memories and the extractor cannot invent labels.
export const MEMORY_CATEGORIES = [
  'family',
  'pets',
  'friends',
  'work',
  'studies',
  'hobbies',
  'preferences',
  'places',
  'routines',
  'goals',
  'other',
] as const;

export type MemoryCategory = (typeof MEMORY_CATEGORIES)[number];

export function isMemoryCategory(value: unknown): value is MemoryCategory {
  return (MEMORY_CATEGORIES as readonly unknown[]).includes(value);
}
