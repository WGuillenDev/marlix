import 'dotenv/config';

import { createClient } from '@supabase/supabase-js';

import { createApp } from './app.js';
import { loadEnv } from './shared/infrastructure/config/env.js';
import { supabaseSessionCheck, verifySupabaseSession } from './modules/identity/infrastructure/supabase-session.js';
import { createSupabaseAccountStore } from './modules/identity/infrastructure/supabase-account-store.js';
import { createSupabaseConversationStore } from './modules/conversation/infrastructure/supabase-conversation-store.js';
import { createSupabaseMessageStore } from './modules/conversation/infrastructure/supabase-message-store.js';
import { createLlmProvider, createQuotaMonitor, GroqTranscriber } from './shared/infrastructure/ai/index.js';
import { createMemoryExtractor } from './modules/memory/infrastructure/extractor.js';
import { createMemoryJob } from './modules/memory/application/memory-job.js';
import { createSupabaseMemoryStore } from './modules/memory/infrastructure/supabase-memory-store.js';
import { createSupabaseProfileStore } from './modules/identity/infrastructure/supabase-profile-store.js';
import { createRetentionJob } from './modules/conversation/application/retention-job.js';
import { createSupabaseUsageStore } from './modules/usage/infrastructure/supabase-usage-store.js';

const env = loadEnv();

const database = createClient(env.SUPABASE_URL, env.SUPABASE_SECRET_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const quota = createQuotaMonitor();

const memories = createSupabaseMemoryStore(database);
const memoryJob = createMemoryJob({
  conversations: createSupabaseConversationStore(database),
  memories,
  extractor: createMemoryExtractor(
    createLlmProvider(env, {
      model: env.MEMORY_EXTRACTOR_MODEL,
      timeoutMs: env.MEMORY_EXTRACTOR_TIMEOUT_MS,
      quota,
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
  llm: createLlmProvider(env, { quota }),
  crisisClassifier: createLlmProvider(env, {
    model: env.CRISIS_CLASSIFIER_MODEL,
    timeoutMs: env.CRISIS_CLASSIFIER_TIMEOUT_MS,
    retry: false,
    quota,
  }),
  quota,
  session: verifySupabaseSession(supabaseSessionCheck(env.SUPABASE_URL)),
  contextMessages: env.CHAT_CONTEXT_MESSAGES,
  messages,
  memories,
  memoryFacts: env.CHAT_MEMORY_FACTS,
  memoryJob,
  accounts: createSupabaseAccountStore(database),
  usage: createSupabaseUsageStore(database),
  profiles: createSupabaseProfileStore(database),
  transcriber: new GroqTranscriber({
    apiKey: env.GROQ_API_KEY,
    model: env.GROQ_TRANSCRIPTION_MODEL,
    baseUrl: env.GROQ_BASE_URL,
    timeoutMs: env.TRANSCRIPTION_TIMEOUT_MS,
  }),
});

const server = app.listen(env.PORT, () => {
  console.log(`marlix api listening on http://localhost:${env.PORT}`);
  memoryJob.start();
  retentionJob.start();
});

// Drain in-flight requests before Render replaces this instance.
process.on('SIGTERM', () => {
  memoryJob.stop();
  retentionJob.stop();
  server.close(() => process.exit(0));
});
