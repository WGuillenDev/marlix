// Measures the whole crisis filter with the real second layer (S2-7), using
// api/.env:  npm run crisis:eval
//
// Runs every invented case of test/fixtures/crisis-cases.ts. Only ambiguous
// messages reach the classifier, one every ~2 seconds to stay under the free
// plan's 30 requests per minute; it spends real quota.
import 'dotenv/config';

import { loadEnv } from '../src/config/env.js';
import { createAmbiguousClassifier } from '../src/services/crisis/classifier.js';
import { createCrisisFilter, detectCrisisSignal } from '../src/services/crisis/filter.js';
import { createLlmProvider } from '../src/services/llm/index.js';
import { ALL_CASES } from '../test/fixtures/crisis-cases.js';

const env = loadEnv();
const llm = createLlmProvider(env, {
  model: env.CRISIS_CLASSIFIER_MODEL,
  timeoutMs: env.CRISIS_CLASSIFIER_TIMEOUT_MS,
  retry: false,
});
const filter = createCrisisFilter(createAmbiguousClassifier(llm));

console.log(`${llm.name} · ${llm.model} · ${ALL_CASES.length} cases\n`);

const matrix = { truePositive: 0, falseNegative: 0, falsePositive: 0, trueNegative: 0 };
const misses: string[] = [];

for (const { message, crisis } of ALL_CASES) {
  const reachesClassifier = detectCrisisSignal(message) === 'ambiguous';
  const decision = await filter.check(message);
  const layer = decision.crisis ? decision.layer : 'none';

  if (crisis && decision.crisis) matrix.truePositive++;
  if (crisis && !decision.crisis) matrix.falseNegative++;
  if (!crisis && decision.crisis) matrix.falsePositive++;
  if (!crisis && !decision.crisis) matrix.trueNegative++;

  const ok = crisis === decision.crisis;
  if (!ok) misses.push(`${crisis ? 'false negative' : 'false positive'}: ${message} (${layer})`);
  const outcome = decision.crisis ? 'crisis' : 'pass  ';
  console.log(`${ok ? 'ok' : 'XX'}  ${outcome}  ${layer.padEnd(18)} ${message}`);

  if (reachesClassifier) await new Promise((resolve) => setTimeout(resolve, 2100));
}

const crisisCases = matrix.truePositive + matrix.falseNegative;
const safeCases = matrix.trueNegative + matrix.falsePositive;
console.log(`
                 decided crisis   decided pass
expected crisis  ${String(matrix.truePositive).padEnd(16)} ${matrix.falseNegative}
expected pass    ${String(matrix.falsePositive).padEnd(16)} ${matrix.trueNegative}

False negatives: ${matrix.falseNegative}/${crisisCases}
False positives: ${matrix.falsePositive}/${safeCases}`);
if (misses.length > 0) console.log(`\n${misses.join('\n')}`);

// A missed crisis is the failure that matters most.
process.exitCode = matrix.falseNegative === 0 ? 0 : 1;
