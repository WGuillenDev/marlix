// Burst limits come from plans.json. Daily caps live in plan_limits.
import { readFileSync } from 'node:fs';

import { z } from 'zod';

import type { PlansConfig } from '../domain/plans.js';

const DEFAULT_PATH = new URL('../../../../config/plans.json', import.meta.url);

const planLimitsSchema = z
  .object({
    rateLimit: z
      .object({
        requests: z.number().int().min(1),
        windowSeconds: z.number().int().min(1),
      })
      .strict(),
  })
  .strict();

const plansSchema = z.record(z.string(), planLimitsSchema).refine((plans) => 'personal' in plans, {
  message: 'The personal plan is required',
});

export class PlansConfigError extends Error {
  constructor(problems: string[]) {
    super(`Invalid plans configuration (api/config/plans.json): ${problems.join('; ')}`);
    this.name = 'PlansConfigError';
  }
}

export function parsePlansConfig(raw: unknown): PlansConfig {
  const result = plansSchema.safeParse(raw);
  if (!result.success) {
    throw new PlansConfigError(
      result.error.issues.map((issue) => `${issue.path.join('.') || 'file'}: ${issue.message}`),
    );
  }
  return result.data;
}

export function loadPlansConfig(path: URL | string = DEFAULT_PATH): PlansConfig {
  return parsePlansConfig(JSON.parse(readFileSync(path, 'utf8')));
}
