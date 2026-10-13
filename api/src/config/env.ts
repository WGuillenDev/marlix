// Environment configuration (S1-2), documented in api/.env.example and the README.
import { z } from 'zod';

// Validated once at startup. Error messages name the variable, never its
// value, so a secret cannot end up in a log.
const envSchema = z.object({
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  // Which LLM provider answers the chat (services/llm/). Each provider has its
  // own variables below; adding one is described in docs/architecture.md.
  LLM_PROVIDER: z.enum(['groq']).default('groq'),
  GROQ_API_KEY: z.string().trim().min(1),
  GROQ_MODEL: z.string().trim().min(1),
});

/** The validated configuration. Code reads it from here, never from process.env. */
export type Env = z.infer<typeof envSchema>;

export class EnvValidationError extends Error {
  constructor(readonly invalidVariables: string[]) {
    super(`Invalid or missing environment variables: ${invalidVariables.join(', ')}`);
    this.name = 'EnvValidationError';
  }
}

/** Parses and validates the given variables. Empty values count as missing. */
export function parseEnv(source: NodeJS.ProcessEnv): Env {
  const withoutEmpty = Object.fromEntries(
    Object.entries(source).filter(([, value]) => value !== undefined && value.trim() !== ''),
  );
  const result = envSchema.safeParse(withoutEmpty);

  if (!result.success) {
    const names = [...new Set(result.error.issues.map((issue) => String(issue.path[0])))];
    throw new EnvValidationError(names.sort());
  }

  return Object.freeze(result.data);
}

/**
 * Validates process.env. On failure it prints which variables are wrong and
 * stops the process: the server must never run half configured.
 */
export function loadEnv(): Env {
  try {
    return parseEnv(process.env);
  } catch (error) {
    if (error instanceof EnvValidationError) {
      console.error(`${error.message}. Copy api/.env.example to api/.env and fill them in.`);
      process.exit(1);
    }
    throw error;
  }
}
