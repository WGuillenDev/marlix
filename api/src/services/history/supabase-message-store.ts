import type { PostgrestError, SupabaseClient } from '@supabase/supabase-js';

import {
  type ContextMessage,
  encodeCursor,
  HistoryStoreError,
  type MessageStore,
  type StoredMessage,
} from './message-store.js';

const COLUMNS = 'id, role, content, created_at, interrupted';

interface MessageRow {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  created_at: string;
  interrupted: boolean;
}

/**
 * Stores the history through the Supabase API with the secret key: the
 * backend is the only writer of messages (docs/schema.sql). Every query
 * filters by user_id itself, because that key bypasses RLS.
 */
export function createSupabaseMessageStore(client: SupabaseClient): MessageStore {
  return {
    async saveTurn(userId, { message, reply, messageAt, crisis }) {
      const conversationId = await openConversation(client, userId);
      // The reply must sort after the message even within the same millisecond.
      const replyAt = new Date(Math.max(Date.now(), messageAt.getTime() + 1));
      const { data, error } = await client
        .from('messages')
        .insert([
          {
            user_id: userId,
            conversation_id: conversationId,
            role: 'user',
            content: message,
            crisis,
            created_at: messageAt.toISOString(),
          },
          {
            user_id: userId,
            conversation_id: conversationId,
            role: 'assistant',
            content: reply,
            crisis,
            created_at: replyAt.toISOString(),
          },
        ])
        .select(COLUMNS);
      if (error) throw fail(error);

      const rows = data as MessageRow[];
      const userRow = rows.find((row) => row.role === 'user');
      const replyRow = rows.find((row) => row.role === 'assistant');
      if (!userRow || !replyRow) throw fail();
      return { userMessage: toMessage(userRow), reply: toMessage(replyRow) };
    },

    async recent(userId, limit) {
      const conversationId = await findOpenConversation(client, userId);
      if (!conversationId) return [];

      const { data, error } = await client
        .from('messages')
        .select('role, content')
        .eq('user_id', userId)
        .eq('conversation_id', conversationId)
        .eq('crisis', false)
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .limit(limit);
      if (error) throw fail(error);
      return (data as ContextMessage[]).reverse();
    },

    async page(userId, { limit, before }) {
      let query = client
        .from('messages')
        .select(COLUMNS)
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        // One more than asked tells whether there are older messages.
        .limit(limit + 1);
      if (before) {
        const { createdAt, id } = before;
        query = query.or(`created_at.lt.${createdAt},and(created_at.eq.${createdAt},id.lt.${id})`);
      }
      const { data, error } = await query;
      if (error) throw fail(error);

      const rows = data as MessageRow[];
      const pageRows = rows.slice(0, limit);
      const oldest = pageRows.at(-1);
      return {
        messages: pageRows.map(toMessage).reverse(),
        nextCursor:
          rows.length > limit && oldest
            ? encodeCursor({ createdAt: oldest.created_at, id: oldest.id })
            : null,
      };
    },

    async markInterrupted(userId, messageId) {
      const { data, error } = await client
        .from('messages')
        .update({ interrupted: true })
        .eq('id', messageId)
        .eq('user_id', userId)
        .eq('role', 'assistant')
        .select('id');
      if (error) throw fail(error);
      return data.length > 0;
    },

    async deleteOlderThan(cutoff) {
      const { count, error } = await client
        .from('messages')
        .delete({ count: 'exact' })
        .lt('created_at', cutoff.toISOString());
      if (error) throw fail(error);
      return count ?? 0;
    },
  };
}

async function findOpenConversation(
  client: SupabaseClient,
  userId: string,
): Promise<string | undefined> {
  const open = await client
    .from('conversations')
    .select('id')
    .eq('user_id', userId)
    .is('ended_at', null)
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (open.error) throw fail(open.error);
  return (open.data?.id as string | undefined) ?? undefined;
}

/** The user's open conversation, or a new one with their avatar. */
async function openConversation(client: SupabaseClient, userId: string): Promise<string> {
  const open = await findOpenConversation(client, userId);
  if (open) return open;

  const profile = await client.from('users').select('avatar_id').eq('id', userId).single();
  if (profile.error) throw fail(profile.error);

  const created = await client
    .from('conversations')
    .insert({ user_id: userId, avatar_id: profile.data.avatar_id })
    .select('id')
    .single();
  if (created.error) throw fail(created.error);
  return created.data.id as string;
}

function toMessage(row: MessageRow): StoredMessage {
  return {
    id: row.id,
    role: row.role,
    content: row.content,
    createdAt: new Date(row.created_at).toISOString(),
    interrupted: row.interrupted,
  };
}

// Only the error code is logged: the database's message and details can quote
// the row being written.
function fail(error?: PostgrestError): HistoryStoreError {
  console.error(`Message store failed: ${error?.code || 'no code'}`);
  return new HistoryStoreError();
}
