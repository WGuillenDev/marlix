import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { createFakeLlm, DEV_TOKEN, startApp } from './helpers.js';

describe('development token on /v1', () => {
  const fake = createFakeLlm();
  let app: Awaited<ReturnType<typeof startApp>>;

  before(async () => {
    app = await startApp({ llm: fake.llm });
  });
  after(() => app.close());

  const rejected: [string, Record<string, string>][] = [
    ['no Authorization header', { authorization: '' }],
    ['a wrong token', { authorization: 'Bearer wrong-token' }],
    ['the right token without the Bearer scheme', { authorization: DEV_TOKEN }],
    ['an empty Bearer token', { authorization: 'Bearer ' }],
  ];

  for (const [name, headers] of rejected) {
    it(`rejects ${name} with 401 UNAUTHORIZED before calling the model`, async () => {
      const callsBefore = fake.requests.length;
      const response = await app.postJson('/v1/chat', { message: 'Hola' }, headers);

      assert.equal(response.status, 401);
      assert.deepEqual(await response.json(), {
        error: { code: 'UNAUTHORIZED', message: 'Missing or invalid token.' },
      });
      assert.equal(fake.requests.length, callsBefore);
    });
  }

  it('lets a request with the right token through', async () => {
    const response = await app.postJson('/v1/chat', { message: 'Hola' });
    assert.equal(response.status, 200);
  });

  it('keeps GET /health public', async () => {
    const response = await app.request('/health');
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: 'ok' });
  });
});
