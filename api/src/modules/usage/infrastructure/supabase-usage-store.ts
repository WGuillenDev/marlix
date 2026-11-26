import type { PostgrestError, SupabaseClient } from '@supabase/supabase-js';

import { UsageStoreError, type UsageStore } from '../application/usage-store.js';

// Cache caps briefly because every chat message reads one.
const CAP_TTL_MS = 60_000;

/** The service key bypasses RLS, so queries must scope data explicitly. */
export function createSupabaseUsageStore(
  client: SupabaseClient,
  now: () => number = Date.now,
): UsageStore {
  const caps = new Map<string, { cap: number | undefined; readAt: number }>();

  return {
    async used(userId, day) {
      const { data, error } = await client
        .from('daily_usage')
        .select('interactions')
        .eq('user_id', userId)
        .eq('usage_date', day)
        .maybeSingle();
      if (error) throw fail(error);
      return (data?.interactions as number | undefined) ?? 0;
    },

    async dailyCap(plan) {
      const known = caps.get(plan);
      if (known && now() - known.readAt < CAP_TTL_MS) return known.cap;

      const { data, error } = await client
        .from('plan_limits')
        .select('daily_interactions')
        .eq('plan', plan)
        .maybeSingle();
      if (error) {
        const failure = fail(error);
        // An outage does not need to stop the chat if the cap is already known.
        if (known) return known.cap;
        throw failure;
      }
      const cap = data?.daily_interactions as number | undefined;
      caps.set(plan, { cap, readAt: now() });
      return cap;
    },

    async record(userId, day) {
      const { data, error } = await client.rpc('record_interaction', {
        p_user_id: userId,
        p_day: day,
      });
      if (error) throw fail(error);
      if (typeof data !== 'number') throw fail();
      return data;
    },
  };
}

function fail(error?: PostgrestError): UsageStoreError {
  console.error(`Usage store failed: ${error?.code || 'no code'}`);
  return new UsageStoreError();
}
