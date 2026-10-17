import type { ContextMessage } from '../history/message-store.js';

export interface PendingConversation {
  id: string;
  userId: string;
}

export interface ConversationStore {
  /**
   * Ends the conversations without activity for `idleSeconds`, of one user or
   * of everybody, and returns how many it ended.
   */
  closeIdle(idleSeconds: number, userId?: string): Promise<number>;
  /** Ended conversations whose memory was not extracted yet, oldest first. */
  listPending(): Promise<PendingConversation[]>;
  /**
   * What was said in a conversation, oldest first, without the messages of a
   * crisis: those never go to the model (S0-8).
   */
  transcript(conversationId: string, userId: string): Promise<ContextMessage[]>;
  markExtracted(conversationId: string, userId: string): Promise<void>;
}
