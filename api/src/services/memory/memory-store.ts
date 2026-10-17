export interface Memory {
  id: string;
  fact: string;
  category: string | null;
  /** ISO 8601. */
  createdAt: string;
  updatedAt: string;
}

export interface MemoryStore {
  list(userId: string): Promise<Memory[]>;
  add(
    userId: string,
    memory: { fact: string; category: string; sourceConversationId: string },
  ): Promise<void>;
  /** Rewrites one of the user's memories; false if they have none with that id. */
  update(userId: string, id: string, change: { fact: string; category: string }): Promise<boolean>;
}
