// Manual check of the configured LLM provider (S1-4), using api/.env.
//
//   npm run llm:smoke              one message, prints the reply
//   npm run llm:smoke -- --burst 6 several calls at once, to force a 429
//
// It spends real quota: the burst uses a few thousand tokens.
import 'dotenv/config';

import { parseArgs } from 'node:util';

import { buildSystemPrompt } from '../src/config/system-prompt.js';
import { loadEnv } from '../src/config/env.js';
import { createLlmProvider, LlmError, type LlmMessage } from '../src/services/llm/index.js';

const { values } = parseArgs({ options: { burst: { type: 'string', default: '1' } } });
const calls = Math.max(1, Number(values.burst) || 1);

const provider = createLlmProvider(loadEnv());
const messages: LlmMessage[] = [
  { role: 'system', content: buildSystemPrompt('text', []) },
  { role: 'user', content: 'Hola, ¿cómo estás? Saludame en una frase corta.' },
];

console.log(`${provider.name} · ${provider.model} · ${calls} call(s)\n`);

const results = await Promise.allSettled(
  Array.from({ length: calls }, () => provider.complete({ messages, maxOutputTokens: 512 })),
);

results.forEach((result, index) => {
  const label = `#${index + 1}`;
  if (result.status === 'fulfilled') {
    const { content, usage } = result.value;
    const tokens = usage ? ` (${usage.inputTokens} in / ${usage.outputTokens} out)` : '';
    console.log(`${label} ok${tokens}: ${content}`);
  } else if (result.reason instanceof LlmError) {
    const { retryAfterSeconds } = result.reason;
    const wait = retryAfterSeconds ? `, retry after ${retryAfterSeconds}s` : '';
    console.log(`${label} ${result.reason.kind}${wait}: ${result.reason.message}`);
  } else {
    console.log(`${label} unexpected error`, result.reason);
  }
});

// A call right after the burst shows the adapter waiting instead of calling Groq.
if (calls > 1) {
  try {
    await provider.complete({ messages, maxOutputTokens: 512 });
    console.log('\nfollow-up call: ok');
  } catch (error) {
    if (!(error instanceof LlmError)) throw error;
    console.log(`\nfollow-up call: ${error.kind} (${error.message})`);
  }
}
