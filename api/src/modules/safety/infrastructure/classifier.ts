import { CRISIS_CLASSIFIER_PROMPT } from './crisis-classifier-prompt.js';
import type { LlmProvider } from '../../../shared/application/ai/types.js';
import type { AmbiguousResolver } from '../application/crisis-filter.js';

// Room for the model's short reasoning plus the one-word answer.
const MAX_OUTPUT_TOKENS = 300;

/** Classify only the current message without history, memories or the personality prompt. */
export function createAmbiguousClassifier(llm: LlmProvider): AmbiguousResolver {
  return async (message) => {
    const { content } = await llm.complete({
      messages: [
        { role: 'system', content: CRISIS_CLASSIFIER_PROMPT },
        { role: 'user', content: message },
      ],
      maxOutputTokens: MAX_OUTPUT_TOKENS,
      temperature: 0,
    });
    return content.trim().toUpperCase().replace(/[^A-Z]/g, '') !== 'SAFE';
  };
}
