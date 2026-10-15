// Environment configuration (S1-2), documented in api/.env.example and the README.
import { z } from 'zod';

// Validated once at startup. Error messages name the variable, never its
// value, so a secret cannot end up in a log.
const envSchema = z.object({
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  // Required on every /v1 request until real auth exists (S1-7, removed in
  // S4-3). Long and random: it is the only thing protecting the chat.
  DEV_ACCESS_TOKEN: z.string().trim().min(32),
  // Which LLM provider answers the chat (services/llm/). Each provider has its
  // own variables below; adding one is described in docs/architecture.md.
  LLM_PROVIDER: z.enum(['groq']).default('groq'),
  // Longest wait for one LLM call before it counts as failed (transient errors
  // are retried once, so a request can wait up to about twice this).
  LLM_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120_000).default(15_000),
  GROQ_API_KEY: z.string().trim().min(1),
  GROQ_MODEL: z.string().trim().min(1),
  GROQ_BASE_URL: z.url().default('https://api.groq.com/openai/v1'),
  // gpt-oss models reason before answering; "low" saves tokens and time.
  // "none" omits the parameter, for models without reasoning.
  GROQ_REASONING_EFFORT: z.enum(['low', 'medium', 'high', 'none']).default('low'),
  // Second layer of the crisis filter (S2-2). A different model than the chat,
  // so it has its own quota. A timeout counts as a crisis, so it stays short.
  CRISIS_CLASSIFIER_MODEL: z.string().trim().min(1).default('openai/gpt-oss-20b'),
  CRISIS_CLASSIFIER_TIMEOUT_MS: z.coerce.number().int().min(1000).max(30_000).default(5000),
  // Supabase project (S4-1). The secret key has service_role rights and
  // bypasses RLS: only the backend holds it, never the app or a log.
  SUPABASE_URL: z.url().refine((url) => /^https:\/\/[a-z0-9]+\.supabase\.co\/?$/.test(url)),
  SUPABASE_SECRET_KEY: z.string().trim().startsWith('sb_secret_'),
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
