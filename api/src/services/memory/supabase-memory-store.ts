import type { SupabaseClient } from '@supabase/supabase-js';

import { databaseFailure } from '../database-error.js';
import type { Memory, MemoryStore } from './memory-store.js';

/**
 * Reads and writes memories through the Supabase API with the secret key, so
 * every query filters by user itself (that key bypasses RLS).
 */
export function createSupabaseMemoryStore(client: SupabaseClient): MemoryStore {
  return {
    async list(userId) {
      const { data, error } = await client
        .from('memories')
        .select('id, fact, category')
        .eq('user_id', userId)
        .order('created_at', { ascending: true });
      if (error) throw databaseFailure('Reading memories', error);
      return data as Memory[];
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
  };
}
