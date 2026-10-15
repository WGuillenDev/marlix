import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { errors, generateKeyPair, SignJWT, UnsecuredJWT } from 'jose';

import {
  captureConsole,
  createFakeLlm,
  signSession,
  startApp,
  TEST_ISSUER,
  TEST_SESSION_CHECK,
} from './helpers.js';

describe('Supabase session on /v1', () => {
  const fake = createFakeLlm();
  let app: Awaited<ReturnType<typeof startApp>>;

  before(async () => {
    app = await startApp({ llm: fake.llm });
  });
  after(() => app.close());

  const bearer = async (token: string | Promise<string>) => ({
    authorization: `Bearer ${await token}`,
  });

  const rejected: [string, () => Promise<Record<string, string>>][] = [
    ['no Authorization header', async () => ({ authorization: '' })],
    ['an empty Bearer token', async () => ({ authorization: 'Bearer ' })],
    [
      'a valid token without the Bearer scheme',
      async () => ({ authorization: await signSession() }),
    ],
    ['something that is not a token', () => bearer('not-a-token')],
    [
      'an expired token',
      () => bearer(signSession({ expiresIn: Math.floor(Date.now() / 1000) - 60 })),
    ],
    [
      'a token from another Supabase project',
      () => bearer(signSession({ claims: { iss: 'https://other.supabase.co/auth/v1' } })),
    ],
    ['a token for another audience', () => bearer(signSession({ claims: { aud: 'anon' } }))],
    [
      'the anon key, which is not a user session',
      () => bearer(signSession({ claims: { role: 'anon' } })),
    ],
    [
      'a token signed with another key',
      async () => bearer(signSession({ privateKey: (await generateKeyPair('ES256')).privateKey })),
    ],
    [
      'an HS256 token signed with a shared secret',
      () =>
        bearer(
          new SignJWT({ role: 'authenticated' })
            .setProtectedHeader({ alg: 'HS256' })
            .setIssuer(TEST_ISSUER)
            .setAudience('authenticated')
            .setSubject('00000000-0000-4000-8000-00000000000a')
            .setExpirationTime('1h')
            .sign(new TextEncoder().encode('a-shared-secret-of-at-least-32-bytes')),
        ),
    ],
    [
      'an unsigned token',
      () =>
        bearer(
          new UnsecuredJWT({ role: 'authenticated' })
            .setIssuer(TEST_ISSUER)
            .setAudience('authenticated')
            .setSubject('00000000-0000-4000-8000-00000000000a')
            .setExpirationTime('1h')
            .encode(),
        ),
    ],
  ];

  for (const [name, headers] of rejected) {
    it(`rejects ${name} with 401 UNAUTHORIZED before calling the model`, async () => {
      const callsBefore = fake.requests.length;
      const response = await app.postJson('/v1/chat', { message: 'Hola' }, await headers());

      assert.equal(response.status, 401);
      assert.deepEqual(await response.json(), {
        error: { code: 'UNAUTHORIZED', message: 'Missing or invalid token.' },
      });
      assert.equal(fake.requests.length, callsBefore);
    });
  }

  it('lets a request with a valid session through', async () => {
    const response = await app.postJson('/v1/chat', { message: 'Hola' });
    assert.equal(response.status, 200);
  });

  it('counts the usage of each user separately', async () => {
    const other = await bearer(
      signSession({ claims: { sub: '00000000-0000-4000-8000-00000000000b' } }),
    );
    const usedBy = async (headers: Record<string, string>) =>
      ((await (await app.request('/v1/usage', { headers })).json()) as { used: number }).used;

    const before = { me: await usedBy(app.authHeader), other: await usedBy(other) };
    await app.postJson('/v1/chat', { message: 'Hola otra vez' }, other);

    assert.equal(await usedBy(app.authHeader), before.me);
    assert.equal(await usedBy(other), before.other + 1);
  });

  it('keeps GET /health and GET /v1/help-resources public', async () => {
    assert.equal((await app.request('/health')).status, 200);
    assert.equal((await app.request('/v1/help-resources')).status, 200);
  });
});

describe('Supabase signing keys unavailable', () => {
  it('answers 500, not 401, so the app does not sign the user out', async () => {
    const app = await startApp({
      llm: createFakeLlm().llm,
      session: {
        issuer: TEST_SESSION_CHECK.issuer,
        keys: () => Promise.reject(new errors.JWKSTimeout()),
      },
    });
    try {
      const { result: response } = await captureConsole(() =>
        app.postJson('/v1/chat', { message: 'Hola' }),
      );
      assert.equal(response.status, 500);
      assert.equal(((await response.json()) as any).error.code, 'INTERNAL_ERROR');
    } finally {
      await app.close();
    }
  });
});
