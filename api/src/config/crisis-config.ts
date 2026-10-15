// Crisis reply text and help resources (S2-3), read from api/config/crisis.json
// so a number can change without touching code or rebuilding the app.
// Protocol: docs/crisis-protocol.md.
import { readFileSync } from 'node:fs';

import { z } from 'zod';

const DEFAULT_PATH = new URL('../../config/crisis.json', import.meta.url);

const helpResourceSchema = z
  .object({
    id: z.string().trim().min(1),
    name: z.string().trim().min(1),
    phone: z.string().regex(/^\d{3,15}$/, 'Must be digits only, ready to dial'),
    hours: z.string().trim().min(1),
    primary: z.boolean(),
  })
  .strict();

// The checks protect the protocol itself: a configuration that would send a
// crisis reply without 9-1-1 as the main option never starts the server.
const crisisConfigSchema = z
  .object({
    updatedAt: z.iso.datetime(),
    reply: z.string().trim().includes('9-1-1', { message: 'Must point to 9-1-1' }),
    resources: z.array(helpResourceSchema).min(1),
  })
  .strict()
  .superRefine(({ resources }, context) => {
    const primaries = resources.filter((resource) => resource.primary);
    if (primaries.length !== 1 || primaries[0]?.phone !== '911' || !resources[0]?.primary) {
      context.addIssue({
        code: 'custom',
        path: ['resources'],
        message: 'Exactly one primary resource, 9-1-1, listed first',
      });
    }
    if (new Set(resources.map((resource) => resource.id)).size !== resources.length) {
      context.addIssue({ code: 'custom', path: ['resources'], message: 'Ids must be unique' });
    }
  });

export type HelpResource = z.infer<typeof helpResourceSchema>;
export type CrisisConfig = z.infer<typeof crisisConfigSchema>;

export class CrisisConfigError extends Error {
  constructor(problems: string[]) {
    super(`Invalid crisis configuration (api/config/crisis.json): ${problems.join('; ')}`);
    this.name = 'CrisisConfigError';
  }
}

export function parseCrisisConfig(raw: unknown): CrisisConfig {
  const result = crisisConfigSchema.safeParse(raw);
  if (!result.success) {
    throw new CrisisConfigError(
      result.error.issues.map((issue) => `${issue.path.join('.') || 'file'}: ${issue.message}`),
    );
  }
  return result.data;
}

export function loadCrisisConfig(path: URL | string = DEFAULT_PATH): CrisisConfig {
  return parseCrisisConfig(JSON.parse(readFileSync(path, 'utf8')));
}
