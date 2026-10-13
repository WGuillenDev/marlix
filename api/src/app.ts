import express, { type ErrorRequestHandler } from 'express';

import { createChatRouter } from './routes/chat.js';
import { healthRouter } from './routes/health.js';
import { createChatService } from './services/chat-service.js';
import type { LlmProvider } from './services/llm/index.js';

export interface AppDependencies {
  llm: LlmProvider;
}

// The JSON parser's error message quotes the start of the body, which can be
// a user's message, so it is answered without logging it.
const handleInvalidJson: ErrorRequestHandler = (error, _req, res, next) => {
  if (error instanceof SyntaxError && 'body' in error) {
    res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: 'The request body is not valid JSON.' },
    });
    return;
  }
  next(error);
};

/** Builds the Express app without listening, so tests can use it directly. */
export function createApp({ llm }: AppDependencies) {
  const app = express();

  // Do not advertise the framework in every response.
  app.disable('x-powered-by');
  // A chat message is at most 2,000 characters; anything far bigger is rejected.
  app.use(express.json({ limit: '16kb' }));

  app.use(healthRouter);
  app.use('/v1', createChatRouter(createChatService(llm)));

  app.use(handleInvalidJson);

  return app;
}
