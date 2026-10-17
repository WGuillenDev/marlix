// Loads api/.env into process.env before anything reads it.
import 'dotenv/config';

import { createClient } from '@supabase/supabase-js';

import { createApp } from './app.js';
import { loadEnv } from './config/env.js';
import { supabaseSessionCheck } from './middleware/require-session.js';
import { createSupabaseMessageStore } from './services/history/supabase-message-store.js';
import { createLlmProvider } from './services/llm/index.js';

const env = loadEnv();
const app = createApp({
  llm: createLlmProvider(env),
  crisisClassifier: createLlmProvider(env, {
    model: env.CRISIS_CLASSIFIER_MODEL,
    timeoutMs: env.CRISIS_CLASSIFIER_TIMEOUT_MS,
    retry: false,
  }),
  session: supabaseSessionCheck(env.SUPABASE_URL),
  messages: createSupabaseMessageStore(
    // No session to keep: the key identifies the backend on every call.
    createClient(env.SUPABASE_URL, env.SUPABASE_SECRET_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    }),
  ),
});

const server = app.listen(env.PORT, () => {
  console.log(`marlix api listening on http://localhost:${env.PORT}`);
});

// Render sends SIGTERM before replacing the instance on each deploy: finish
// the requests in flight instead of cutting them.
process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});
