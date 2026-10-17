import type { SupabaseClient } from '@supabase/supabase-js';

import { databaseFailure } from '../database-error.js';
import type { Memory, MemoryStore } from './memory-store.js';

const COLUMNS = 'id, fact, category, created_at, updated_at';

interface MemoryRow {
  id: string;
  fact: string;
  category: string | null;
  created_at: string;
  updated_at: string;
}

/**
 * Reads and writes memories through the Supabase API with the secret key, so
 * every query filters by user itself (that key bypasses RLS).
 */
export function createSupabaseMemoryStore(client: SupabaseClient): MemoryStore {
  return {
    async list(userId) {
      const { data, error } = await client
        .from('memories')
        .select(COLUMNS)
        .eq('user_id', userId)
        .order('created_at', { ascending: true });
      if (error) throw databaseFailure('Reading memories', error);
      return (data as MemoryRow[]).map(toMemory);
    },

    async add(userId, { fact, category, sourceConversationId }) {
      const { error } = await client.from('memories').insert({
        user_id: userId,
        fact,
        category,
        source_conversation_id: sourceConversationId,
      });
      if (error) throw databaseFailure('Saving a memory', error);
    },

    async update(userId, id, { fact, category }) {
      const { data, error } = await client
        .from('memories')
        .update({ fact, category })
        .eq('id', id)
        .eq('user_id', userId)
        .select('id');
      if (error) throw databaseFailure('Updating a memory', error);
      return data.length > 0;
    },

    async edit(userId, id, fact) {
      const { data, error } = await client
        .from('memories')
        .update({ fact })
        .eq('id', id)
        .eq('user_id', userId)
        .select(COLUMNS);
      if (error) throw databaseFailure('Editing a memory', error);
      const [row] = data as MemoryRow[];
      return row ? toMemory(row) : null;
    },

    async remove(userId, id) {
      const { data, error } = await client
        .from('memories')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .select('id');
      if (error) throw databaseFailure('Deleting a memory', error);
      return data.length > 0;
    },

    async removeAll(userId) {
      const { error } = await client.from('memories').delete().eq('user_id', userId);
      if (error) throw databaseFailure('Deleting the memories', error);
    },
  };
}

function toMemory(row: MemoryRow): Memory {
  return {
    id: row.id,
    fact: row.fact,
    category: row.category,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
