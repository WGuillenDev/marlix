// Second layer of the crisis filter (S2-2): an isolated classification of
// ambiguous messages. Protocol: docs/crisis-protocol.md.
import { CRISIS_CLASSIFIER_PROMPT } from '../../config/crisis-classifier-prompt.js';
import type { LlmProvider } from '../llm/index.js';
import type { AmbiguousResolver } from './filter.js';

// Room for the model's short reasoning plus the one-word answer.
const MAX_OUTPUT_TOKENS = 300;

/**
 * Sends only the current message with the classification policy: no history,
 * no memory and no personality prompt. Only an exact "SAFE" lets the message
 * through; any other answer is a crisis, and errors or timeouts are handled
 * as a crisis by the filter.
 */
export function createAmbiguousClassifier(llm: LlmProvider): AmbiguousResolver {
  return async (message) => {
    const { content } = await llm.complete({
      messages: [
        { role: 'system', content: CRISIS_CLASSIFIER_PROMPT },
        { role: 'user', content: message },
      ],
      maxOutputTokens: MAX_OUTPUT_TOKENS,
    });
    return content.trim().toUpperCase().replace(/[^A-Z]/g, '') !== 'SAFE';
  };
}
