import express from 'express';

import { loadCrisisConfig, type CrisisConfig } from './config/crisis-config.js';
import { errorHandler, notFoundHandler } from './middleware/error-handler.js';
import { requireDevToken } from './middleware/require-dev-token.js';
import { createChatRouter } from './routes/chat.js';
import { healthRouter } from './routes/health.js';
import { createHelpResourcesRouter } from './routes/help-resources.js';
import { createChatService } from './services/chat-service.js';
import {
  createConsoleActivationLog,
  type ActivationLog,
} from './services/crisis/activation-log.js';
import { createAmbiguousClassifier } from './services/crisis/classifier.js';
import { createCrisisFilter } from './services/crisis/filter.js';
import type { LlmProvider } from './services/llm/index.js';

export interface AppDependencies {
  llm: LlmProvider;
  /** Classifies ambiguous messages (S2-2). Without it, they are a crisis. */
  crisisClassifier?: LlmProvider;
  /** Token every /v1 request must carry until real auth exists (S4-3). */
  devAccessToken: string;
  /** Crisis text and help resources; read from api/config/crisis.json by default. */
  crisisConfig?: CrisisConfig;
  /** Where crisis activations are recorded (S2-5); the logs by default. */
  activationLog?: ActivationLog;
}

/** Builds the Express app without listening, so tests can use it directly. */
export function createApp({
  llm,
  crisisClassifier,
  devAccessToken,
  crisisConfig = loadCrisisConfig(),
  activationLog = createConsoleActivationLog(),
}: AppDependencies) {
  const app = express();

  // Do not advertise the framework in every response.
  app.disable('x-powered-by');
  // A chat message is at most 2,000 characters; anything far bigger is rejected.
  app.use(express.json({ limit: '16kb' }));

  // Public: the uptime monitor calls it.
  app.use(healthRouter);
  // Public: the help screen must work without a session or token.
  app.use('/v1', createHelpResourcesRouter(crisisConfig));

  const crisisFilter = createCrisisFilter(
    crisisClassifier ? createAmbiguousClassifier(crisisClassifier) : undefined,
  );
  const chatService = createChatService(llm, crisisFilter, activationLog);
  app.use('/v1', requireDevToken(devAccessToken), createChatRouter(chatService, crisisConfig));

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
