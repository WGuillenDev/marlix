import { Router } from 'express';

import type { UsageLimiter } from '../services/usage/usage-limiter.js';

// GET /health (docs/api-contract.md). Public and outside /v1: the uptime
// monitor calls it every 10 minutes. It never touches the database or Groq: it
// only reports what the last real requests found. It answers 200 even when
// degraded, because Render restarts the service after a failed health check
// and a restart does not fix a missing database function (S6-16).
export function createHealthRouter(usage: Pick<UsageLimiter, 'isCounting'>) {
  const router = Router();

  router.get('/health', (_req, res) => {
    if (usage.isCounting()) {
      res.status(200).json({ status: 'ok' });
      return;
    }
    res.status(200).json({ status: 'degraded', problems: ['usage_counter'] });
  });

  return router;
}
