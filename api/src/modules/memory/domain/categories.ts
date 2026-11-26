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
