import { randomUUID } from 'node:crypto';

import type {
  ConversationStore,
  PendingConversation,
} from '../src/services/conversations/conversation-store.js';
import type { ContextMessage } from '../src/services/history/message-store.js';
import type { MemoryChange, MemoryExtractor } from '../src/services/memory/extractor.js';
import type { AccountStore } from '../src/services/account/account-store.js';
import type { Memory, MemoryStore } from '../src/services/memory/memory-store.js';

interface FakeConversation extends PendingConversation {
  messages: ContextMessage[];
  ended: boolean;
  extracted: boolean;
  /** Whether `closeIdle` ends it, as if it had no messages for long enough. */
  idle: boolean;
}

/** Conversations in memory; the test decides which ones are idle. */
export function createFakeConversations() {
  const conversations: FakeConversation[] = [];
  let closeError: Error | undefined;

  const store: ConversationStore = {
    async closeIdle(_idleSeconds, userId) {
      if (closeError) throw closeError;
      const idle = conversations.filter(
        (c) => !c.ended && c.idle && (userId === undefined || c.userId === userId),
      );
      for (const conversation of idle) conversation.ended = true;
      return idle.length;
    },
    async listPending() {
      return conversations
        .filter((c) => c.ended && !c.extracted)
        .map(({ id, userId }) => ({ id, userId }));
    },
    async transcript(conversationId, userId) {
      const found = conversations.find((c) => c.id === conversationId && c.userId === userId);
      return found ? [...found.messages] : [];
    },
    async markExtracted(conversationId, userId) {
      const found = conversations.find((c) => c.id === conversationId && c.userId === userId);
      if (found) found.extracted = true;
    },
  };

  return {
    store,
    conversations,
    add(
      userId: string,
      messages: ContextMessage[],
      { ended = true, idle = false }: { ended?: boolean; idle?: boolean } = {},
    ) {
      const conversation: FakeConversation = {
        id: randomUUID(),
        userId,
        messages,
        ended,
        extracted: false,
        idle,
      };
      conversations.push(conversation);
      return conversation;
    },
    failClosing(error: Error | undefined) {
      closeError = error;
    },
  };
}

export function said(...texts: string[]): ContextMessage[] {
  return texts.flatMap((text) => [
    { role: 'user' as const, content: text },
    { role: 'assistant' as const, content: 'Cuéntame más.' },
  ]);
}

/** Memories in memory, with the same ownership rules as the database. */
type FakeMemory = Memory & { userId: string };

export function createFakeMemories(
  initial: (Pick<Memory, 'id' | 'fact' | 'category'> & { userId: string })[] = [],
) {
  let clock = Date.parse('2026-10-01T12:00:00.000Z');
  const tick = () => new Date((clock += 1000)).toISOString();
  const rows: FakeMemory[] = initial.map((row) => ({
    ...row,
    createdAt: tick(),
    updatedAt: tick(),
  }));

  const store: MemoryStore = {
    async list(userId) {
      return rows
        .filter((row) => row.userId === userId)
        .map(({ userId: _userId, ...memory }) => memory);
    },
    async add(userId, { fact, category }) {
      const now = tick();
      rows.push({ id: randomUUID(), userId, fact, category, createdAt: now, updatedAt: now });
    },
    async update(userId, id, { fact, category }) {
      const row = rows.find((r) => r.id === id && r.userId === userId);
      if (row) Object.assign(row, { fact, category, updatedAt: tick() });
      return row !== undefined;
    },
    async edit(userId, id, fact) {
      const row = rows.find((r) => r.id === id && r.userId === userId);
      if (!row) return null;
      Object.assign(row, { fact, updatedAt: tick() });
      const { userId: _userId, ...memory } = row;
      return memory;
    },
    async remove(userId, id) {
      const index = rows.findIndex((r) => r.id === id && r.userId === userId);
      if (index >= 0) rows.splice(index, 1);
      return index >= 0;
    },
    async removeAll(userId) {
      for (let i = rows.length - 1; i >= 0; i--) if (rows[i]!.userId === userId) rows.splice(i, 1);
    },
  };

  return { store, rows };
}

/** An extractor that records what it was given and answers with `respond`. */
export function createFakeExtractor(
  respond: (input: Parameters<MemoryExtractor['extract']>[0]) => MemoryChange[] | Promise<MemoryChange[]> = () => [],
) {
  const calls: Parameters<MemoryExtractor['extract']>[0][] = [];
  const extractor: MemoryExtractor = {
    async extract(input) {
      calls.push(input);
      return respond(input);
    },
  };
  return { extractor, calls };
}

/** Records the accounts that were deleted. */
export function createFakeAccounts() {
  const deleted: string[] = [];
  const store: AccountStore = {
    async deleteAccount(userId) {
      deleted.push(userId);
    },
  };
  return { store, deleted };
}
