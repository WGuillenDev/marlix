// Loads api/.env into process.env before anything reads it.
import 'dotenv/config';

import { createApp } from './app.js';
import { loadEnv } from './config/env.js';
import { createLlmProvider } from './services/llm/index.js';

const env = loadEnv();
const app = createApp({ llm: createLlmProvider(env), devAccessToken: env.DEV_ACCESS_TOKEN });

const server = app.listen(env.PORT, () => {
  console.log(`marlix api listening on http://localhost:${env.PORT}`);
});

// Render sends SIGTERM before replacing the instance on each deploy: finish
// the requests in flight instead of cutting them.
process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});
