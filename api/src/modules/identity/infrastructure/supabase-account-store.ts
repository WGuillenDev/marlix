import type { SupabaseClient } from '@supabase/supabase-js';

import { DatabaseError } from '../../../shared/infrastructure/persistence/database-error.js';
import type { AccountStore } from '../application/account-store.js';

/** A hard delete is required to cascade through the user's data. */
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
