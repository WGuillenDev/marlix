import { z } from 'zod';

export const DEFAULT_CONTEXT_MESSAGES = 16;
export const DEFAULT_MEMORY_FACTS = 30;
export const DEFAULT_RETENTION_DAYS = 90;

// Validation reports variable names only so secret values stay out of logs.
const envSchema = z.object({
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  LLM_PROVIDER: z.enum(['groq']).default('groq'),
  LLM_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120_000).default(15_000),
  GROQ_API_KEY: z.string().trim().min(1),
  GROQ_MODEL: z.string().trim().min(1),
  GROQ_BASE_URL: z.url().default('https://api.groq.com/openai/v1'),
  // Use "none" to omit reasoning effort for models that do not support it.
  GROQ_REASONING_EFFORT: z.enum(['low', 'medium', 'high', 'none']).default('low'),
  GROQ_TRANSCRIPTION_MODEL: z.string().trim().min(1).default('whisper-large-v3-turbo'),
  TRANSCRIPTION_TIMEOUT_MS: z.coerce.number().int().min(1000).max(60_000).default(15_000),
  // Classifier timeouts trigger the crisis protocol, so keep this deadline short.
  CRISIS_CLASSIFIER_MODEL: z.string().trim().min(1).default('openai/gpt-oss-20b'),
  CRISIS_CLASSIFIER_TIMEOUT_MS: z.coerce.number().int().min(1000).max(30_000).default(5000),
  CHAT_CONTEXT_MESSAGES: z.coerce.number().int().min(2).max(40).default(DEFAULT_CONTEXT_MESSAGES),
  CONVERSATION_IDLE_MINUTES: z.coerce.number().int().min(1).max(1440).default(30),
  MEMORY_EXTRACTOR_MODEL: z.string().trim().min(1).default('openai/gpt-oss-20b'),
  MEMORY_EXTRACTOR_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120_000).default(30_000),
  CHAT_MEMORY_FACTS: z.coerce.number().int().min(1).max(50).default(DEFAULT_MEMORY_FACTS),
  // Retention removes raw messages without deleting distilled memories.
  MESSAGE_RETENTION_DAYS: z.coerce.number().int().min(1).max(3650).default(DEFAULT_RETENTION_DAYS),
  // The backend-only Supabase key bypasses row-level security.
  SUPABASE_URL: z.url().refine((url) => /^https:\/\/[a-z0-9]+\.supabase\.co\/?$/.test(url)),
  SUPABASE_SECRET_KEY: z.string().trim().startsWith('sb_secret_'),
});

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
