// Loads api/.env into process.env before anything reads it.
import 'dotenv/config';

import { createApp } from './app.js';
import { loadEnv } from './config/env.js';
import { createLlmProvider } from './services/llm/index.js';

const env = loadEnv();
const app = createApp({ llm: createLlmProvider(env) });

app.listen(env.PORT, () => {
  console.log(`marlix api listening on http://localhost:${env.PORT}`);
});
