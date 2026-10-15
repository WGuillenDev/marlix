import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { createFakeLlm, startApp } from './helpers.js';

const EXPECTED = {
  'strict-transport-security': 'max-age=31536000; includeSubDomains',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
  'content-security-policy': "default-src 'none'; frame-ancestors 'none'",
};

function assertSecurityHeaders(response: Response) {
  for (const [name, value] of Object.entries(EXPECTED)) {
    assert.equal(response.headers.get(name), value, name);
  }
  assert.equal(response.headers.get('x-powered-by'), null);
}

describe('security headers', () => {
  let app: Awaited<ReturnType<typeof startApp>>;

  before(async () => {
    app = await startApp({ llm: createFakeLlm().llm });
  });
  after(() => app.close());

  it('are on GET /health', async () => {
    assertSecurityHeaders(await app.request('/health'));
  });

  it('are on POST /v1/chat, with no-store', async () => {
    const response = await app.postJson('/v1/chat', { message: 'hola' });
    assert.equal(response.status, 200);
    assertSecurityHeaders(response);
    assert.equal(response.headers.get('cache-control'), 'no-store');
  });

  it('are on the crisis reply, with no-store', async () => {
    const response = await app.postJson('/v1/chat', { message: 'me quiero morir' });
    assertSecurityHeaders(response);
    assert.equal(response.headers.get('cache-control'), 'no-store');
  });

  it('are on the public help resources, with no-store', async () => {
    const response = await app.request('/v1/help-resources');
    assertSecurityHeaders(response);
    assert.equal(response.headers.get('cache-control'), 'no-store');
  });

  const errors: [string, () => Promise<Response>, number][] = [
    ['a 401 without the token', () => app.request('/v1/usage'), 401],
    ['a 400 for malformed JSON', () => app.postJson('/v1/chat', '{"message": '), 400],
    ['a 404 outside /v1', () => app.request('/nothing-here'), 404],
  ];

  for (const [name, send, status] of errors) {
    it(`are on ${name}`, async () => {
      const response = await send();
      assert.equal(response.status, status);
      assertSecurityHeaders(response);
    });
  }
});
