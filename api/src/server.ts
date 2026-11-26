import 'dotenv/config';

import { createApp } from './bootstrap/app.js';
import { buildContainer } from './bootstrap/container.js';
import { loadEnv } from './shared/infrastructure/config/env.js';

const env = loadEnv();
const { dependencies, memoryJob, retentionJob } = buildContainer(env);
const app = createApp(dependencies);

const server = app.listen(env.PORT, () => {
  console.log(`marlix api listening on http://localhost:${env.PORT}`);
  memoryJob.start();
  retentionJob.start();
});

// Drain in-flight requests before Render replaces this instance.
process.on('SIGTERM', () => {
  memoryJob.stop();
  retentionJob.stop();
  server.close(() => process.exit(0));
});
