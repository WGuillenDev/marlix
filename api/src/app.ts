import express from 'express';

import { errorHandler, notFoundHandler } from './middleware/error-handler.js';
import { requireDevToken } from './middleware/require-dev-token.js';
import { createChatRouter } from './routes/chat.js';
import { healthRouter } from './routes/health.js';
import { createChatService } from './services/chat-service.js';
import { createCrisisFilter } from './services/crisis/filter.js';
import type { LlmProvider } from './services/llm/index.js';

export interface AppDependencies {
  llm: LlmProvider;
  /** Token every /v1 request must carry until real auth exists (S4-3). */
  devAccessToken: string;
}

/** Builds the Express app without listening, so tests can use it directly. */
export function createApp({ llm, devAccessToken }: AppDependencies) {
  const app = express();

  // Do not advertise the framework in every response.
  app.disable('x-powered-by');
  // A chat message is at most 2,000 characters; anything far bigger is rejected.
  app.use(express.json({ limit: '16kb' }));

  // Public: the uptime monitor calls it.
  app.use(healthRouter);
  const chatService = createChatService(llm, createCrisisFilter());
  app.use('/v1', requireDevToken(devAccessToken), createChatRouter(chatService));

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
