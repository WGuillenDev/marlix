import type { MemoryStore } from './memory-store.js';

export function createMemoryManagement(store: MemoryStore) {
  return {
    async list(userId: string) {
      return (await store.list(userId)).toReversed();
    },
    edit: (userId: string, id: string, fact: string) => store.edit(userId, id, fact),
    remove: (userId: string, id: string) => store.remove(userId, id),
    removeAll: (userId: string) => store.removeAll(userId),
  };
}
