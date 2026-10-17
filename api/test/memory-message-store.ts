import { randomUUID } from 'node:crypto';

import {
  encodeCursor,
  type MessageStore,
  type StoredMessage,
} from '../src/services/history/message-store.js';

/** A MessageStore that keeps everything in memory, with the database's ordering rules. */
export function createMemoryMessageStore() {
  const rows: (StoredMessage & { userId: string })[] = [];
  let clock = Date.parse('2026-10-01T12:00:00.000Z');
  let failing = false;

  const store: MessageStore = {
    async saveTurn(userId, { message, reply }) {
      if (failing) throw new Error('store down');
      const make = (role: StoredMessage['role'], content: string) => {
        clock += 1000;
        const row = {
          userId,
          id: randomUUID(),
          role,
          content,
          createdAt: new Date(clock).toISOString(),
          interrupted: false,
        };
        rows.push(row);
        return toMessage(row);
      };
      return { userMessage: make('user', message), reply: make('assistant', reply) };
    },

    async page(userId, { limit, before }) {
      const newestFirst = rows
        .filter((row) => row.userId === userId)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt) || b.id.localeCompare(a.id))
        .filter(
          (row) =>
            !before ||
            row.createdAt < before.createdAt ||
            (row.createdAt === before.createdAt && row.id < before.id),
        );
      const pageRows = newestFirst.slice(0, limit);
      const oldest = pageRows.at(-1);
      return {
        messages: pageRows.map(toMessage).reverse(),
        nextCursor:
          newestFirst.length > limit && oldest
            ? encodeCursor({ createdAt: oldest.createdAt, id: oldest.id })
            : null,
      };
    },

    async markInterrupted(userId, messageId) {
      const row = rows.find(
        (r) => r.id === messageId && r.userId === userId && r.role === 'assistant',
      );
      if (row) row.interrupted = true;
      return row !== undefined;
    },
  };

  return {
    store,
    rows,
    /** Makes every save fail, like a database outage. */
    setFailing(value: boolean) {
      failing = value;
    },
  };
}

function toMessage({ userId: _userId, ...message }: StoredMessage & { userId: string }) {
  return message;
}
