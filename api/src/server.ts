// Loads api/.env into process.env before anything reads it.
import 'dotenv/config';

import { createClient } from '@supabase/supabase-js';

import { createApp } from './app.js';
import { loadEnv } from './config/env.js';
import { supabaseSessionCheck } from './middleware/require-session.js';
import { createSupabaseAccountStore } from './services/account/supabase-account-store.js';
import { createSupabaseConversationStore } from './services/conversations/supabase-conversation-store.js';
import { createSupabaseMessageStore } from './services/history/supabase-message-store.js';
import { createLlmProvider } from './services/llm/index.js';
import { createMemoryExtractor } from './services/memory/extractor.js';
import { createMemoryJob } from './services/memory/memory-job.js';
import { createSupabaseMemoryStore } from './services/memory/supabase-memory-store.js';
import { createSupabaseProfileStore } from './services/profile/supabase-profile-store.js';
import { createRetentionJob } from './services/retention/retention-job.js';
import { createSupabaseUsageStore } from './services/usage/supabase-usage-store.js';

const env = loadEnv();

// No session to keep: the key identifies the backend on every call.
const database = createClient(env.SUPABASE_URL, env.SUPABASE_SECRET_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const memories = createSupabaseMemoryStore(database);
const memoryJob = createMemoryJob({
  conversations: createSupabaseConversationStore(database),
  memories,
  extractor: createMemoryExtractor(
    createLlmProvider(env, {
      model: env.MEMORY_EXTRACTOR_MODEL,
      timeoutMs: env.MEMORY_EXTRACTOR_TIMEOUT_MS,
    }),
  ),
  idleSeconds: env.CONVERSATION_IDLE_MINUTES * 60,
});

const messages = createSupabaseMessageStore(database);
const retentionJob = createRetentionJob({
  messages,
  retentionDays: env.MESSAGE_RETENTION_DAYS,
});

const app = createApp({
  llm: createLlmProvider(env),
  crisisClassifier: createLlmProvider(env, {
    model: env.CRISIS_CLASSIFIER_MODEL,
    timeoutMs: env.CRISIS_CLASSIFIER_TIMEOUT_MS,
    retry: false,
  }),
  session: supabaseSessionCheck(env.SUPABASE_URL),
  contextMessages: env.CHAT_CONTEXT_MESSAGES,
  messages,
  memories,
  memoryFacts: env.CHAT_MEMORY_FACTS,
  memoryJob,
  accounts: createSupabaseAccountStore(database),
  usage: createSupabaseUsageStore(database),
  profiles: createSupabaseProfileStore(database),
});

const server = app.listen(env.PORT, () => {
  console.log(`marlix api listening on http://localhost:${env.PORT}`);
  memoryJob.start();
  retentionJob.start();
});

// Render sends SIGTERM before replacing the instance on each deploy: finish
// the requests in flight instead of cutting them.
process.on('SIGTERM', () => {
  memoryJob.stop();
  retentionJob.stop();
  server.close(() => process.exit(0));
});
