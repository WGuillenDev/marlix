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
  /** The person edits the text of one memory (US-08); null if they have none with that id. */
  edit(userId: string, id: string, fact: string): Promise<Memory | null>;
  /** Deletes one memory; false if they have none with that id. */
  remove(userId: string, id: string): Promise<boolean>;
  removeAll(userId: string): Promise<void>;
}
