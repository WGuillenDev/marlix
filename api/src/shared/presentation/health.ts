import { Router } from 'express';

import type { QuotaStatus } from '../application/ai/quota-status.js';
import type { UsageLimiter } from '../../modules/usage/application/usage-limiter.js';

// Report degradation without failing the liveness check and triggering a restart.
export function createHealthRouter(
  usage: Pick<UsageLimiter, 'isCounting'>,
  quota?: QuotaStatus,
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
