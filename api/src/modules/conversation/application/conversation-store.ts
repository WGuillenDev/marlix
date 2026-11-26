import type { ContextMessage } from './message-store.js';

export interface PendingConversation {
  id: string;
  userId: string;
}

export interface ConversationStore {
  closeIdle(idleSeconds: number, userId?: string): Promise<number>;
  listPending(): Promise<PendingConversation[]>;
  /** Excludes crisis messages so they never enter a model prompt. */
  transcript(conversationId: string, userId: string): Promise<ContextMessage[]>;
  markExtracted(conversationId: string, userId: string): Promise<void>;
}
