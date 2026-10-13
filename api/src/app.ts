import express from 'express';

import { errorHandler, notFoundHandler } from './middleware/error-handler.js';
import { createChatRouter } from './routes/chat.js';
import { healthRouter } from './routes/health.js';
import { createChatService } from './services/chat-service.js';
import type { LlmProvider } from './services/llm/index.js';

export interface AppDependencies {
  llm: LlmProvider;
}

/** Builds the Express app without listening, so tests can use it directly. */
export function createApp({ llm }: AppDependencies) {
  const app = express();

  // Do not advertise the framework in every response.
  app.disable('x-powered-by');
  // A chat message is at most 2,000 characters; anything far bigger is rejected.
  app.use(express.json({ limit: '16kb' }));

  app.use(healthRouter);
  app.use('/v1', createChatRouter(createChatService(llm)));

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
