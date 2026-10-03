import express from 'express';

import { healthRouter } from './routes/health.js';

// Builds the Express app without listening, so tests can use it directly.
export function createApp() {
  const app = express();

  // Do not advertise the framework in every response.
  app.disable('x-powered-by');
  app.use(express.json());

  app.use(healthRouter);

  return app;
}
