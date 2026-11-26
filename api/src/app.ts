import express from 'express';

import { createChatService } from './modules/conversation/application/chat-service.js';
import type { MessageStore } from './modules/conversation/application/message-store.js';
import type { Transcriber } from './modules/conversation/application/transcriber.js';
import { createChatRouter } from './modules/conversation/presentation/chat.js';
import { createHistoryRouter } from './modules/conversation/presentation/history.js';
import { createTranscribeRouter } from './modules/conversation/presentation/transcribe.js';

import type { AccountStore } from './modules/identity/application/account-store.js';
import type { ProfileStore } from './modules/identity/application/profile-store.js';
import type { SessionVerifier } from './modules/identity/application/session-verifier.js';
import { createAccountRouter } from './modules/identity/presentation/account.js';
import { createProfileRouter } from './modules/identity/presentation/profile.js';

import { createMemoryManagement } from './modules/memory/application/manage-memories.js';
import type { MemoryJob } from './modules/memory/application/memory-job.js';
import type { MemoryStore } from './modules/memory/application/memory-store.js';
import { selectForPrompt } from './modules/memory/domain/prompt-memories.js';
import { createMemoriesRouter } from './modules/memory/presentation/memories.js';

import type { ActivationLog } from './modules/safety/application/activation-log.js';
import { createCrisisFilter } from './modules/safety/application/crisis-filter.js';
import type { CrisisConfig } from './modules/safety/domain/crisis-config.js';
import { createAmbiguousClassifier } from './modules/safety/infrastructure/classifier.js';
import { createConsoleActivationLog } from './modules/safety/infrastructure/console-activation-log.js';
import { loadCrisisConfig } from './modules/safety/infrastructure/crisis-config.js';
import { createHelpResourcesRouter } from './modules/safety/presentation/help-resources.js';

import type { QuotaStatus } from './shared/application/ai/quota-status.js';
import type { LlmProvider } from './shared/application/ai/types.js';
import { DEFAULT_CONTEXT_MESSAGES, DEFAULT_MEMORY_FACTS } from './shared/infrastructure/config/env.js';
import { errorHandler, notFoundHandler } from './shared/presentation/error-handler.js';
import { createHealthRouter } from './shared/presentation/health.js';
import { requireSession } from './shared/presentation/require-session.js';
import { noStore, securityHeaders } from './shared/presentation/security-headers.js';

import { createUsageLimiter } from './modules/usage/application/usage-limiter.js';
import type { UsageStore } from './modules/usage/application/usage-store.js';
import type { PlansConfig } from './modules/usage/domain/plans.js';
import { loadPlansConfig } from './modules/usage/infrastructure/plans.js';
import { createUsageRouter } from './modules/usage/presentation/usage.js';

export interface AppDependencies {
  llm: LlmProvider;
  /** Ambiguous messages trigger the crisis protocol if no classifier is configured. */
  crisisClassifier?: LlmProvider;
  session: SessionVerifier;
  messages: MessageStore;
  contextMessages?: number;
  memories: MemoryStore;
  memoryFacts?: number;
  /** Without this job, idle conversations stay open. */
  memoryJob?: Pick<MemoryJob, 'endIdleConversation'>;
  accounts: AccountStore;
  usage: UsageStore;
  profiles: ProfileStore;
  transcriber: Transcriber;
  quota?: QuotaStatus;
  crisisConfig?: CrisisConfig;
  activationLog?: ActivationLog;
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
  quota,
  crisisConfig = loadCrisisConfig(),
  activationLog = createConsoleActivationLog(),
  plans = loadPlansConfig(),
}: AppDependencies) {
  const app = express();

  app.disable('x-powered-by');
  app.use(securityHeaders);
  app.use(express.json({ limit: '16kb' }));

  const usageLimiter = createUsageLimiter(plans, usage);

  app.use(createHealthRouter(usageLimiter, quota));
  // Help resources are available before sign-in.
  app.use('/v1', noStore, createHelpResourcesRouter(crisisConfig));

  const crisisFilter = createCrisisFilter(
    crisisClassifier ? createAmbiguousClassifier(crisisClassifier) : undefined,
  );
  const chatService = createChatService({
    llm,
    crisisFilter,
    activationLog,
    usageLimiter,
    messages,
    crisisReply: crisisConfig.reply,
    contextMessages,
    endIdleConversation: (userId) => memoryJob?.endIdleConversation(userId) ?? Promise.resolve(),
    promptMemories: async (userId) => selectForPrompt(await memories.list(userId), memoryFacts),
  });
  app.use(
    '/v1',
    requireSession(session),
    createChatRouter(chatService, crisisConfig),
    createHistoryRouter(messages),
    createMemoriesRouter(createMemoryManagement(memories)),
    createAccountRouter(accounts),
    createProfileRouter(profiles),
    createUsageRouter(usageLimiter),
    createTranscribeRouter(transcriber, usageLimiter),
  );

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
