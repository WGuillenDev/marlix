import express from 'express';

import { loadCrisisConfig, type CrisisConfig } from './config/crisis-config.js';
import { DEFAULT_CONTEXT_MESSAGES, DEFAULT_MEMORY_FACTS } from './config/env.js';
import { loadPlansConfig, type PlansConfig } from './config/plans.js';
import { errorHandler, notFoundHandler } from './middleware/error-handler.js';
import { requireSession, type SessionCheck } from './middleware/require-session.js';
import { noStore, securityHeaders } from './middleware/security-headers.js';
import { createChatRouter } from './routes/chat.js';
import { createHealthRouter } from './routes/health.js';
import { createHelpResourcesRouter } from './routes/help-resources.js';
import { createAccountRouter } from './routes/account.js';
import { createHistoryRouter } from './routes/history.js';
import { createMemoriesRouter } from './routes/memories.js';
import { createProfileRouter } from './routes/profile.js';
import { createTranscribeRouter } from './routes/transcribe.js';
import { createUsageRouter } from './routes/usage.js';
import { createChatService } from './services/chat-service.js';
import {
  createConsoleActivationLog,
  type ActivationLog,
} from './services/crisis/activation-log.js';
import { createAmbiguousClassifier } from './services/crisis/classifier.js';
import { createCrisisFilter } from './services/crisis/filter.js';
import type { AccountStore } from './services/account/account-store.js';
import type { MessageStore } from './services/history/message-store.js';
import type { MemoryJob } from './services/memory/memory-job.js';
import type { MemoryStore } from './services/memory/memory-store.js';
import type { ProfileStore } from './services/profile/profile-store.js';
import { selectForPrompt } from './services/memory/prompt-memories.js';
import type { LlmProvider } from './services/llm/index.js';
import type { Transcriber } from './services/transcription/transcriber.js';
import { createUsageLimiter } from './services/usage/usage-limiter.js';
import type { UsageStore } from './services/usage/usage-store.js';

export interface AppDependencies {
  llm: LlmProvider;
  /** Classifies ambiguous messages (S2-2). Without it, they are a crisis. */
  crisisClassifier?: LlmProvider;
  /** How /v1 requests are checked for a Supabase session (S4-3). */
  session: SessionCheck;
  /** Where the chat history is saved (S4-4). */
  messages: MessageStore;
  /** How many messages of the conversation the model sees (S4-5). */
  contextMessages?: number;
  /** The distilled memory: the prompt is built from it (S4-7) and the person manages it (S4-8). */
  memories: MemoryStore;
  /** How many memories go into the prompt (S4-7). */
  memoryFacts?: number;
  /** Ends idle conversations and extracts their memory (S4-6). Without it, nothing ends. */
  memoryJob?: Pick<MemoryJob, 'endIdleConversation'>;
  /** Deletes the person's account and, in cascade, all their data (S4-9). */
  accounts: AccountStore;
  /** Where the daily counters and caps are (S4-13). */
  usage: UsageStore;
  /** The profile and the onboarding state (S5-5). */
  profiles: ProfileStore;
  /** Turns the voice mode's audio into text (S6-9). */
  transcriber: Transcriber;
  /** Crisis text and help resources; read from api/config/crisis.json by default. */
  crisisConfig?: CrisisConfig;
  /** Where crisis activations are recorded (S2-5); the logs by default. */
  activationLog?: ActivationLog;
  /** Burst limits per plan (S2-6); read from api/config/plans.json by default. */
  plans?: PlansConfig;
}

/** Builds the Express app without listening, so tests can use it directly. */
export function createApp({
  llm,
  crisisClassifier,
  session,
  messages,
  contextMessages = DEFAULT_CONTEXT_MESSAGES,
  memories,
  memoryFacts = DEFAULT_MEMORY_FACTS,
  memoryJob,
  accounts,
  usage,
  profiles,
  transcriber,
  crisisConfig = loadCrisisConfig(),
  activationLog = createConsoleActivationLog(),
  plans = loadPlansConfig(),
}: AppDependencies) {
  const app = express();

  // Do not advertise the framework in every response.
  app.disable('x-powered-by');
  app.use(securityHeaders);
  // A chat message is at most 2,000 characters; anything far bigger is rejected.
  app.use(express.json({ limit: '16kb' }));

  const usageLimiter = createUsageLimiter(plans, usage);

  // Public: the uptime monitor calls it.
  app.use(createHealthRouter(usageLimiter));
  // Public: the help screen must work without a session or token.
  app.use('/v1', noStore, createHelpResourcesRouter(crisisConfig));

  const crisisFilter = createCrisisFilter(
    crisisClassifier ? createAmbiguousClassifier(crisisClassifier) : undefined,
  );
  const chatService = createChatService(
    llm,
    crisisFilter,
    activationLog,
    usageLimiter,
    messages,
    crisisConfig.reply,
    contextMessages,
    (userId) => memoryJob?.endIdleConversation(userId) ?? Promise.resolve(),
    async (userId) => selectForPrompt(await memories.list(userId), memoryFacts),
  );
  app.use(
    '/v1',
    requireSession(session),
    createChatRouter(chatService, crisisConfig),
    createHistoryRouter(messages),
    createMemoriesRouter(memories),
    createAccountRouter(accounts),
    createProfileRouter(profiles),
    createUsageRouter(usageLimiter),
    createTranscribeRouter(transcriber, usageLimiter),
  );

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
