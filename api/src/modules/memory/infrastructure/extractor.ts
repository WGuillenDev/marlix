import { z } from 'zod';

import { MEMORY_EXTRACTOR_PROMPT } from './memory-extractor-prompt.js';
import type { ContextMessage } from '../../conversation/application/message-store.js';
import type { LlmProvider } from '../../../shared/application/ai/types.js';
import type { MemoryExtractor } from '../application/memory-extractor.js';
import { acceptChanges } from '../domain/extraction-policy.js';
import type { MemoryChange, SavedFact } from '../domain/memory.js';

// Use recent conversation text to keep extraction within the shared token quota.
const MAX_TRANSCRIPT_CHARS = 12_000;
const MAX_OUTPUT_TOKENS = 1500;

export class MemoryExtractionError extends Error {
  constructor() {
    super('The extractor did not return a valid answer');
    this.name = 'MemoryExtractionError';
  }
}

const answerSchema = z.object({
  memories: z.array(
    z.object({
      id: z.string().nullable().optional(),
      fact: z.string(),
      category: z.string().optional(),
    }),
  ),
});

export function createMemoryExtractor(llm: LlmProvider): MemoryExtractor {
  return {
    async extract({ transcript, existing }) {
      const { content } = await llm.complete({
        messages: [
          { role: 'system', content: MEMORY_EXTRACTOR_PROMPT },
          { role: 'user', content: describe(transcript, existing) },
        ],
        maxOutputTokens: MAX_OUTPUT_TOKENS,
        temperature: 0,
      });
      return parseChanges(content, existing);
    },
  };
}

function describe(transcript: ContextMessage[], existing: SavedFact[]): string {
  const saved = existing.length > 0 ? existing.map((m) => `[${m.id}] ${m.fact}`).join('\n') : '(none)';

  const lines: string[] = [];
  let total = 0;
  for (const message of transcript.toReversed()) {
    const line = `${message.role === 'user' ? 'Persona' : 'marlix'}: ${message.content}`;
    if (total + line.length > MAX_TRANSCRIPT_CHARS) break;
    lines.unshift(line);
    total += line.length;
  }

  return `Existing memories:\n${saved}\n\nConversation:\n${lines.join('\n')}`;
}

/** Treat model output as untrusted. Reject sensitive facts and treat unknown IDs as new facts. */
export function parseChanges(content: string, existing: SavedFact[]): MemoryChange[] {
  const start = content.indexOf('{');
  const end = content.lastIndexOf('}');
  let parsed: z.infer<typeof answerSchema>;
  try {
    parsed = answerSchema.parse(JSON.parse(content.slice(start, end + 1)));
  } catch {
    throw new MemoryExtractionError();
  }

  return acceptChanges(parsed.memories, existing);
}
