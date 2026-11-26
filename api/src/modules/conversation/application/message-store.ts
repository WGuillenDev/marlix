
export interface StoredMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  createdAt: string;
  interrupted: boolean;
}

export interface HistoryPage {
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
  /** Saves both messages atomically. Crisis turns remain in history only. */
  saveTurn(
    userId: string,
    turn: { message: string; reply: string; messageAt: Date; crisis: boolean },
  ): Promise<SavedTurn>;
  /** Returns recent messages oldest first and excludes crisis turns from model context. */
  recent(userId: string, limit: number): Promise<ContextMessage[]>;
  /** Newest page first; `before` is a `nextCursor` already checked by `decodeCursor`. */
  page(userId: string, options: { limit: number; before?: Cursor }): Promise<HistoryPage>;
  markInterrupted(userId: string, messageId: string): Promise<boolean>;
  deleteOlderThan(cutoff: Date): Promise<number>;
}

export interface Cursor {
  /** Keep the database timestamp as written so cursor precision is preserved. */
  createdAt: string;
  id: string;
}

const TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function encodeCursor({ createdAt, id }: Cursor): string {
  return Buffer.from(`${createdAt}|${id}`).toString('base64url');
}

/** Validate the cursor before inserting its values into a database filter. */
export function decodeCursor(value: string): Cursor | undefined {
  const [createdAt, id, ...rest] = Buffer.from(value, 'base64url').toString().split('|');
  if (rest.length > 0 || !createdAt || !id) return undefined;
  if (!TIMESTAMP.test(createdAt) || Number.isNaN(Date.parse(createdAt)) || !UUID.test(id)) {
    return undefined;
  }
  return { createdAt, id };
}

export class MessageNotFoundError extends Error {
  constructor() {
    super('Message not found');
    this.name = 'MessageNotFoundError';
  }
}

export class HistoryStoreError extends Error {
  constructor() {
    super('The message store failed');
    this.name = 'HistoryStoreError';
  }
}
