import express from 'express';

import { loadCrisisConfig, type CrisisConfig } from './config/crisis-config.js';
import { DEFAULT_CONTEXT_MESSAGES } from './config/env.js';
import { loadPlansConfig, type PlansConfig } from './config/plans.js';
import { errorHandler, notFoundHandler } from './middleware/error-handler.js';
import { requireSession, type SessionCheck } from './middleware/require-session.js';
import { noStore, securityHeaders } from './middleware/security-headers.js';
import { createChatRouter } from './routes/chat.js';
import { healthRouter } from './routes/health.js';
import { createHelpResourcesRouter } from './routes/help-resources.js';
import { createHistoryRouter } from './routes/history.js';
import { createUsageRouter } from './routes/usage.js';
import { createChatService } from './services/chat-service.js';
import {
  createConsoleActivationLog,
  type ActivationLog,
} from './services/crisis/activation-log.js';
import { createAmbiguousClassifier } from './services/crisis/classifier.js';
import { createCrisisFilter } from './services/crisis/filter.js';
import type { MessageStore } from './services/history/message-store.js';
import type { MemoryJob } from './services/memory/memory-job.js';
import type { LlmProvider } from './services/llm/index.js';
import { createUsageLimiter } from './services/usage/usage-limiter.js';

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
  /** Ends idle conversations and extracts their memory (S4-6). Without it, nothing ends. */
  memoryJob?: Pick<MemoryJob, 'endIdleConversation'>;
  /** Crisis text and help resources; read from api/config/crisis.json by default. */
  crisisConfig?: CrisisConfig;
  /** Where crisis activations are recorded (S2-5); the logs by default. */
  activationLog?: ActivationLog;
  /** Usage limits per plan (S2-6); read from api/config/plans.json by default. */
  plans?: PlansConfig;
}

/** Builds the Express app without listening, so tests can use it directly. */
export function createApp({
  llm,
  crisisClassifier,
  session,
  messages,
  contextMessages = DEFAULT_CONTEXT_MESSAGES,
  memoryJob,
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

  // Public: the uptime monitor calls it.
  app.use(healthRouter);
  // Public: the help screen must work without a session or token.
  app.use('/v1', noStore, createHelpResourcesRouter(crisisConfig));

  const crisisFilter = createCrisisFilter(
    crisisClassifier ? createAmbiguousClassifier(crisisClassifier) : undefined,
  );
  const usageLimiter = createUsageLimiter(plans);
  const chatService = createChatService(
    llm,
    crisisFilter,
    activationLog,
    usageLimiter,
    messages,
    crisisConfig.reply,
    contextMessages,
    (userId) => memoryJob?.endIdleConversation(userId) ?? Promise.resolve(),
  );
  app.use(
    '/v1',
    requireSession(session),
    createChatRouter(chatService, crisisConfig, usageLimiter),
    createHistoryRouter(messages),
    createUsageRouter(usageLimiter),
  );

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
