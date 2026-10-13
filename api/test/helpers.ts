import type { AddressInfo } from 'node:net';

import { createApp, type AppDependencies } from '../src/app.js';
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

/** Starts the app on a free port and returns a fetch bound to it. */
export async function startApp(dependencies: AppDependencies) {
  const server = createApp(dependencies).listen(0);
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const { port } = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${port}`;

  return {
    request: (path: string, init?: RequestInit) => fetch(`${baseUrl}${path}`, init),
    postJson: (path: string, body: unknown, headers: Record<string, string> = {}) =>
      fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...headers },
        body: typeof body === 'string' ? body : JSON.stringify(body),
      }),
    close: () => new Promise<void>((resolve) => server.close(() => resolve())),
  };
}

/** Runs `action` while capturing everything written to console.log/error. */
export async function captureConsole<T>(action: () => Promise<T>) {
  const lines: string[] = [];
  const original = { log: console.log, error: console.error, warn: console.warn };
  const record = (...args: unknown[]) => {
    const parts = args.map((arg) =>
      arg instanceof Error ? (arg.stack ?? arg.message) : String(arg),
    );
    lines.push(parts.join(' '));
  };
  console.log = record;
  console.error = record;
  console.warn = record;
  try {
    return { result: await action(), output: lines.join('\n') };
  } finally {
    Object.assign(console, original);
  }
}
