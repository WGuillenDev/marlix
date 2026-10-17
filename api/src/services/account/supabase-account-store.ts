import type { SupabaseClient } from '@supabase/supabase-js';

import { DatabaseError } from '../database-error.js';
import type { AccountStore } from './account-store.js';

/**
 * Deletes the user in Supabase Auth, which needs the secret key. It is a hard
 * delete: a soft-deleted user would keep its rows.
 */
export function createSupabaseAccountStore(client: SupabaseClient): AccountStore {
  return {
    async deleteAccount(userId) {
      const { error } = await client.auth.admin.deleteUser(userId, false);
      if (error && error.code !== 'user_not_found') {
        console.error(`Deleting an account failed: ${error.code || 'no code'}`);
        throw new DatabaseError();
      }
    },
  };
}
