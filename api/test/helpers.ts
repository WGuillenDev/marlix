import type { AddressInfo } from 'node:net';

import { createApp } from '../src/app.js';
import type { CrisisConfig } from '../src/config/crisis-config.js';
import type { PlansConfig } from '../src/config/plans.js';
import type { ActivationLog } from '../src/services/crisis/activation-log.js';
import { LlmError } from '../src/services/llm/index.js';
import type { LlmCompletionRequest, LlmProvider } from '../src/services/llm/index.js';

/** An LlmProvider that records every request and answers with `respond`. */
export function createFakeLlm(
  respond: (request: LlmCompletionRequest) => string | Promise<string> = () => '¡Qué dicha!',
) {
  const requests: LlmCompletionRequest[] = [];
  const llm: LlmProvider = {
    name: 'fake',
    model: 'fake-model',
    async complete(request) {
      requests.push(request);
      return { content: await respond(request) };
    },
  };
  return { llm, requests };
}

export function failingLlm(error: LlmError): LlmProvider {
  return {
    name: 'fake',
    model: 'fake-model',
    complete: () => Promise.reject(error),
  };
}

// Tests send many messages to one app; the real limits are tested on their own.
const GENEROUS_PLANS: PlansConfig = {
  personal: { dailyInteractions: 1000, rateLimit: { requests: 1000, windowSeconds: 60 } },
};

export const DEV_TOKEN = 'test-dev-token-0123456789abcdefghij';
const AUTH_HEADER = { authorization: `Bearer ${DEV_TOKEN}` };

/**
 * Starts the app on a free port. `postJson` sends the development token
 * unless the test passes its own authorization header.
 */
export async function startApp({
  llm,
  crisisClassifier,
  crisisConfig,
  activationLog = { record: () => {} },
  plans = GENEROUS_PLANS,
}: {
  llm: LlmProvider;
  crisisClassifier?: LlmProvider;
  crisisConfig?: CrisisConfig;
  activationLog?: ActivationLog;
  plans?: PlansConfig;
}) {
  const app = createApp({
    llm,
    ...(crisisClassifier ? { crisisClassifier } : {}),
    ...(crisisConfig ? { crisisConfig } : {}),
    activationLog,
    plans,
    devAccessToken: DEV_TOKEN,
  });
  const server = app.listen(0);
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const { port } = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${port}`;

  return {
    request: (path: string, init?: RequestInit) => fetch(`${baseUrl}${path}`, init),
    postJson: (path: string, body: unknown, headers: Record<string, string> = {}) =>
      fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...AUTH_HEADER, ...headers },
        body: typeof body === 'string' ? body : JSON.stringify(body),
      }),
    close: () => new Promise<void>((resolve) => server.close(() => resolve())),
  };
}

/** Runs `action` while capturing everything written to the console. */
export async function captureConsole<T>(action: () => Promise<T>) {
  const lines: string[] = [];
  const original = {
    log: console.log,
    info: console.info,
    error: console.error,
    warn: console.warn,
  };
  const record = (...args: unknown[]) => {
    const parts = args.map((arg) =>
      arg instanceof Error ? (arg.stack ?? arg.message) : String(arg),
    );
    lines.push(parts.join(' '));
  };
  console.log = record;
  console.info = record;
  console.error = record;
  console.warn = record;
  try {
    return { result: await action(), output: lines.join('\n') };
  } finally {
    Object.assign(console, original);
  }
}
