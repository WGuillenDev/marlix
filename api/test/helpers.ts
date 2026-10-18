import type { AddressInfo } from 'node:net';

import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWTPayload } from 'jose';

import { createApp, type AppDependencies } from '../src/app.js';
import type { CrisisConfig } from '../src/config/crisis-config.js';
import type { PlansConfig } from '../src/config/plans.js';
import type { SessionCheck } from '../src/middleware/require-session.js';
import type { ActivationLog } from '../src/services/crisis/activation-log.js';
import type { MessageStore } from '../src/services/history/message-store.js';
import { LlmError } from '../src/services/llm/index.js';
import type { LlmCompletionRequest, LlmProvider } from '../src/services/llm/index.js';
import { createFakeAccounts, createFakeMemories } from './memory-fakes.js';
import { createMemoryMessageStore } from './memory-message-store.js';
import { createMemoryUsageStore } from './memory-usage-store.js';

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
  personal: { rateLimit: { requests: 1000, windowSeconds: 60 } },
};

// A stand-in for the Supabase project: its own signing key and issuer.
export const TEST_ISSUER = 'https://testproject.supabase.co/auth/v1';
const signingKeys = await generateKeyPair('ES256');
const TEST_KID = 'test-key';
const publicJwk = { ...(await exportJWK(signingKeys.publicKey)), kid: TEST_KID, alg: 'ES256' };
export const TEST_SESSION_CHECK = {
  issuer: TEST_ISSUER,
  keys: createLocalJWKSet({ keys: [publicJwk] }),
};

export const TEST_USER_ID = '00000000-0000-4000-8000-00000000000a';

/**
 * Signs an access token like the ones Supabase Auth issues. `claims` and
 * `expiresIn` override the defaults to build invalid tokens.
 */
export function signSession({
  claims = {},
  expiresIn = '1h',
  privateKey = signingKeys.privateKey,
}: {
  claims?: JWTPayload;
  expiresIn?: string | number;
  privateKey?: typeof signingKeys.privateKey;
} = {}) {
  return new SignJWT({
    iss: TEST_ISSUER,
    aud: 'authenticated',
    sub: TEST_USER_ID,
    role: 'authenticated',
    // Signed in just now, like a token that Supabase issued at the sign-in.
    amr: [{ method: 'password', timestamp: Math.floor(Date.now() / 1000) }],
    ...claims,
  })
    .setProtectedHeader({ alg: 'ES256', kid: TEST_KID })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(privateKey);
}

/**
 * Starts the app on a free port. `postJson` sends a valid session token
 * unless the test passes its own authorization header.
 */
export async function startApp({
  llm,
  crisisClassifier,
  crisisConfig,
  activationLog = { record: () => {} },
  plans = GENEROUS_PLANS,
  session = TEST_SESSION_CHECK,
  messages = createMemoryMessageStore().store,
  contextMessages,
  memories = createFakeMemories().store,
  memoryFacts,
  memoryJob,
  accounts = createFakeAccounts().store,
  usage = createMemoryUsageStore().store,
}: {
  llm: LlmProvider;
  crisisClassifier?: LlmProvider;
  crisisConfig?: CrisisConfig;
  activationLog?: ActivationLog;
  plans?: PlansConfig;
  session?: SessionCheck;
  messages?: MessageStore;
  contextMessages?: number;
  memories?: AppDependencies['memories'];
  memoryFacts?: number;
  memoryJob?: AppDependencies['memoryJob'];
  accounts?: AppDependencies['accounts'];
  usage?: AppDependencies['usage'];
}) {
  const app = createApp({
    llm,
    ...(crisisClassifier ? { crisisClassifier } : {}),
    ...(crisisConfig ? { crisisConfig } : {}),
    activationLog,
    plans,
    session,
    messages,
    ...(contextMessages ? { contextMessages } : {}),
    memories,
    ...(memoryFacts ? { memoryFacts } : {}),
    ...(memoryJob ? { memoryJob } : {}),
    accounts,
    usage,
  });
  const authHeader = { authorization: `Bearer ${await signSession()}` };
  const server = app.listen(0);
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const { port } = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${port}`;

  return {
    /** The header `postJson` sends, for requests made with `request`. */
    authHeader,
    request: (path: string, init?: RequestInit) => fetch(`${baseUrl}${path}`, init),
    postJson: (path: string, body: unknown, headers: Record<string, string> = {}) =>
      fetch(`${baseUrl}${path}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...authHeader, ...headers },
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
