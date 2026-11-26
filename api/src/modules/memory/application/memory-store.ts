import type { Memory } from '../domain/memory.js';

export interface MemoryStore {
  list(userId: string): Promise<Memory[]>;
  add(
    userId: string,
    memory: { fact: string; category: string; sourceConversationId: string },
  ): Promise<void>;
  update(userId: string, id: string, change: { fact: string; category: string }): Promise<boolean>;
  edit(userId: string, id: string, fact: string): Promise<Memory | null>;
  remove(userId: string, id: string): Promise<boolean>;
  removeAll(userId: string): Promise<void>;
}
