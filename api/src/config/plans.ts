// Usage limits per plan (S2-6), read from api/config/plans.json. It mirrors the
// plan_limits table (docs/schema.sql) until the backend reads that table in
// Sprint 4. A paid plan (V2-2) is a new entry, not new code.
import { readFileSync } from 'node:fs';

import { z } from 'zod';

const DEFAULT_PATH = new URL('../../config/plans.json', import.meta.url);

const planLimitsSchema = z
  .object({
    /** Successful replies per day; the day follows Costa Rica time. */
    dailyInteractions: z.number().int().min(1),
    /** Burst protection: at most `requests` messages to the model per window. */
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

export type PlanLimits = z.infer<typeof planLimitsSchema>;
export type PlansConfig = z.infer<typeof plansSchema>;

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
