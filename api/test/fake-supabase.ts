import { createClient } from '@supabase/supabase-js';

export interface Call {
  method: string;
  table: string;
  params: URLSearchParams;
  body: unknown;
}

/** Stands in for the Supabase API: records each call and answers from `respond`. */
export function fakeSupabaseClient(
  respond: (call: Call) => { status?: number; body: unknown; headers?: Record<string, string> },
) {
  const calls: Call[] = [];
  const client = createClient('https://testproject.supabase.co', 'sb_secret_test', {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      fetch: async (input, init) => {
        const url = new URL(input instanceof Request ? input.url : String(input));
        const call: Call = {
          method: init?.method ?? 'GET',
          table: url.pathname.split('/').at(-1)!,
          params: url.searchParams,
          body: init?.body ? JSON.parse(String(init.body)) : undefined,
        };
        calls.push(call);
        const { status = 200, body, headers = {} } = respond(call);
        return new Response(status === 204 ? null : JSON.stringify(body), {
          status,
          headers: { 'content-type': 'application/json', ...headers },
        });
      },
    },
  });
  return { client, calls };
}
