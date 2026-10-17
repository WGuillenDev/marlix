import type { SupabaseClient } from '@supabase/supabase-js';

import { databaseFailure } from '../database-error.js';
import type { ContextMessage } from '../history/message-store.js';
import type { ConversationStore } from './conversation-store.js';

// A long conversation is read from its newest part (the extractor cuts
// further), and this keeps one query under the API's row limit.
const MAX_TRANSCRIPT_MESSAGES = 200;
const MAX_PENDING_PER_SWEEP = 50;

/**
 * Reads and writes conversations through the Supabase API with the secret
 * key, so every query filters by user itself (that key bypasses RLS).
 */
export function createSupabaseConversationStore(client: SupabaseClient): ConversationStore {
  return {
    async closeIdle(idleSeconds, userId) {
      const { data, error } = await client.rpc('close_idle_conversations', {
        p_idle_seconds: idleSeconds,
        p_user_id: userId ?? null,
      });
      if (error) throw databaseFailure('Ending idle conversations', error);
      return (data as string[]).length;
    },

    async listPending() {
      const { data, error } = await client
        .from('conversations')
        .select('id, user_id')
        .not('ended_at', 'is', null)
        .is('memory_extracted_at', null)
        .order('ended_at', { ascending: true })
        .limit(MAX_PENDING_PER_SWEEP);
      if (error) throw databaseFailure('Listing pending conversations', error);
      return (data as { id: string; user_id: string }[]).map((row) => ({
        id: row.id,
        userId: row.user_id,
      }));
    },

    async transcript(conversationId, userId) {
      const { data, error } = await client
        .from('messages')
        .select('role, content')
        .eq('conversation_id', conversationId)
        .eq('user_id', userId)
        .eq('crisis', false)
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .limit(MAX_TRANSCRIPT_MESSAGES);
      if (error) throw databaseFailure('Reading a conversation', error);
      return (data as ContextMessage[]).reverse();
    },

    async markExtracted(conversationId, userId) {
      const { error } = await client
        .from('conversations')
        .update({ memory_extracted_at: new Date().toISOString() })
        .eq('id', conversationId)
        .eq('user_id', userId);
      if (error) throw databaseFailure('Marking a conversation as extracted', error);
    },
  };
}
