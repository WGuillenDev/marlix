// Loads api/.env into process.env before anything reads it.
import 'dotenv/config';

import { createClient } from '@supabase/supabase-js';

import { createApp } from './app.js';
import { loadEnv } from './config/env.js';
import { supabaseSessionCheck } from './middleware/require-session.js';
import { createSupabaseConversationStore } from './services/conversations/supabase-conversation-store.js';
import { createSupabaseMessageStore } from './services/history/supabase-message-store.js';
import { createLlmProvider } from './services/llm/index.js';
import { createMemoryExtractor } from './services/memory/extractor.js';
import { createMemoryJob } from './services/memory/memory-job.js';
import { createSupabaseMemoryStore } from './services/memory/supabase-memory-store.js';

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

const app = createApp({
  llm: createLlmProvider(env),
  crisisClassifier: createLlmProvider(env, {
    model: env.CRISIS_CLASSIFIER_MODEL,
    timeoutMs: env.CRISIS_CLASSIFIER_TIMEOUT_MS,
    retry: false,
  }),
  session: supabaseSessionCheck(env.SUPABASE_URL),
  contextMessages: env.CHAT_CONTEXT_MESSAGES,
  messages: createSupabaseMessageStore(database),
  memories,
  memoryFacts: env.CHAT_MEMORY_FACTS,
  memoryJob,
});

const server = app.listen(env.PORT, () => {
  console.log(`marlix api listening on http://localhost:${env.PORT}`);
  memoryJob.start();
});

// Render sends SIGTERM before replacing the instance on each deploy: finish
// the requests in flight instead of cutting them.
process.on('SIGTERM', () => {
  memoryJob.stop();
  server.close(() => process.exit(0));
});
