// Third layer of the memory (S4-6): turns a finished conversation into facts.
import { z } from 'zod';

import { MEMORY_EXTRACTOR_PROMPT } from '../../config/memory-extractor-prompt.js';
import type { ContextMessage } from '../history/message-store.js';
import type { LlmProvider } from '../llm/index.js';
import { isMemoryCategory, type MemoryCategory } from './categories.js';
import type { Memory } from './memory-store.js';
import { isSensitive, sameFact } from './sensitive.js';

// The newest part of a long conversation is what is still true; the rest would
// also spend Groq's per-minute quota.
const MAX_TRANSCRIPT_CHARS = 12_000;
const MAX_CHANGES = 10;
const MAX_FACT_LENGTH = 500;
// Room for the model's reasoning plus the JSON.
const MAX_OUTPUT_TOKENS = 1500;

/** A fact to save: `id` is the memory it rewrites, or null if it is new. */
export interface MemoryChange {
  id: string | null;
  fact: string;
  category: MemoryCategory;
}

/** What the extractor needs to know about a saved memory. */
type SavedFact = Pick<Memory, 'id' | 'fact'>;

export interface MemoryExtractor {
  extract(input: { transcript: ContextMessage[]; existing: SavedFact[] }): Promise<MemoryChange[]>;
}

/** The model answered something that is not the expected JSON. */
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

/**
 * Takes the model's answer as untrusted: only well-formed, non-sensitive
 * facts get through, ids it made up count as new facts, and a fact that is
 * already saved is not a change.
 */
export function parseChanges(content: string, existing: SavedFact[]): MemoryChange[] {
  const start = content.indexOf('{');
  const end = content.lastIndexOf('}');
  let parsed: z.infer<typeof answerSchema>;
  try {
    parsed = answerSchema.parse(JSON.parse(content.slice(start, end + 1)));
  } catch {
    throw new MemoryExtractionError();
  }

  const known = new Map(existing.map((memory) => [memory.id, memory]));
  const changes: MemoryChange[] = [];
  for (const item of parsed.memories) {
    const fact = item.fact.trim();
    if (fact.length === 0 || fact.length > MAX_FACT_LENGTH || isSensitive(fact)) continue;

    const target = item.id ? known.get(item.id) : undefined;
    const unchanged = target
      ? sameFact(target.fact, fact)
      : existing.some((memory) => sameFact(memory.fact, fact));
    const repeated = changes.some((change) => sameFact(change.fact, fact));
    if (unchanged || repeated) continue;

    changes.push({
      id: target?.id ?? null,
      fact,
      category: isMemoryCategory(item.category) ? item.category : 'other',
    });
    if (changes.length === MAX_CHANGES) break;
  }
  return changes;
}
