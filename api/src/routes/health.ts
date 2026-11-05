import { Router } from 'express';

import type { QuotaMonitor } from '../services/llm/index.js';
import type { UsageLimiter } from '../services/usage/usage-limiter.js';

// GET /health (docs/api-contract.md). Public and outside /v1: the uptime
// monitor calls it every 10 minutes. It never touches the database or Groq: it
// only reports what the last real requests found. It answers 200 even when
// degraded, because Render restarts the service after a failed health check
// and a restart does not fix a missing database function (S6-16) or a quota
// that Groq will only renew at the end of the day (S7-6).
export function createHealthRouter(
  usage: Pick<UsageLimiter, 'isCounting'>,
  quota?: Pick<QuotaMonitor, 'isLow'>,
) {
  const router = Router();

  router.get('/health', (_req, res) => {
    const problems: string[] = [];
    if (!usage.isCounting()) problems.push('usage_counter');
    if (quota?.isLow()) problems.push('groq_quota');

    res
      .status(200)
      .json(problems.length === 0 ? { status: 'ok' } : { status: 'degraded', problems });
  });

  return router;
}
