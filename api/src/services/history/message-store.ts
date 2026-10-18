// Chat history (S4-4). Contract: docs/api-contract.md#get-v1history.

export interface StoredMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  /** ISO 8601 in UTC. */
  createdAt: string;
  interrupted: boolean;
}

export interface HistoryPage {
  /** Oldest first, ready to render. */
  messages: StoredMessage[];
  /** Pass it as `before` to load the page of older messages; null at the end. */
  nextCursor: string | null;
}

export interface SavedTurn {
  userMessage: StoredMessage;
  reply: StoredMessage;
}

export interface ContextMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface MessageStore {
  /**
   * Saves the user's message and marlix's reply together, or neither. A
   * `crisis` turn stays in the history but is never part of the context.
   */
  saveTurn(
    userId: string,
    turn: { message: string; reply: string; messageAt: Date; crisis: boolean },
  ): Promise<SavedTurn>;
  /**
   * The last `limit` messages of the user's open conversation, oldest first,
   * without the ones of a crisis: those never go to the model (S0-8).
   */
  recent(userId: string, limit: number): Promise<ContextMessage[]>;
  /** Newest page first; `before` is a `nextCursor` already checked by `decodeCursor`. */
  page(userId: string, options: { limit: number; before?: Cursor }): Promise<HistoryPage>;
  /** Marks one of the user's own replies as interrupted; false if there is none with that id. */
  markInterrupted(userId: string, messageId: string): Promise<boolean>;
  /** Deletes the messages of everybody created before `cutoff` (S4-10) and returns how many. */
  deleteOlderThan(cutoff: Date): Promise<number>;
}

/** Where a page ends: the position of its oldest message. */
export interface Cursor {
  /** As the database wrote it, so no precision is lost. */
  createdAt: string;
  id: string;
}

const TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function encodeCursor({ createdAt, id }: Cursor): string {
  return Buffer.from(`${createdAt}|${id}`).toString('base64url');
}

/**
 * Only a well-formed cursor gets through, because the store puts its parts
 * in a query filter. Returns undefined for anything else.
 */
export function decodeCursor(value: string): Cursor | undefined {
  const [createdAt, id, ...rest] = Buffer.from(value, 'base64url').toString().split('|');
  if (rest.length > 0 || !createdAt || !id) return undefined;
  if (!TIMESTAMP.test(createdAt) || Number.isNaN(Date.parse(createdAt)) || !UUID.test(id)) {
    return undefined;
  }
  return { createdAt, id };
}

/** An interruptedMessageId that is not one of the user's replies. Mapped to 404. */
export class MessageNotFoundError extends Error {
  constructor() {
    super('Message not found');
    this.name = 'MessageNotFoundError';
  }
}

/**
 * The database failed. It carries no message on purpose: the database's text
 * can quote the row, that is, the user's message.
 */
export class HistoryStoreError extends Error {
  constructor() {
    super('The message store failed');
    this.name = 'HistoryStoreError';
  }
}
