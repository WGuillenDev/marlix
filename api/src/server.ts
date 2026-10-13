// Loads api/.env into process.env before anything reads it.
import 'dotenv/config';

import { createApp } from './app.js';
import { loadEnv } from './config/env.js';

const env = loadEnv();

createApp().listen(env.PORT, () => {
  console.log(`marlix api listening on http://localhost:${env.PORT}`);
});
