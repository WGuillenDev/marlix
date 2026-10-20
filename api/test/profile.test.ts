import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { createFakeProfiles } from './memory-profiles.js';
import { createFakeLlm, startApp } from './helpers.js';

const USER = '00000000-0000-4000-8000-00000000000a';

describe('GET /v1/me and POST /v1/onboarding', () => {
  const { store, profiles } = createFakeProfiles();
  let app: Awaited<ReturnType<typeof startApp>>;

  before(async () => {
    app = await startApp({ llm: createFakeLlm().llm, profiles: store });
  });
  after(() => app.close());

  const me = () => app.request('/v1/me', { headers: app.authHeader });

  it('requires a session', async () => {
    assert.equal((await app.request('/v1/me')).status, 401);
    const response = await app.request('/v1/onboarding', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ dataConsent: true, remindersEnabled: false }),
    });
    assert.equal(response.status, 401);
  });

  it('returns the profile in the contract shape, with onboarding still open for a new user', async () => {
    const response = await me();
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      id: USER,
      plan: 'personal',
      avatar: {
        id: '0b8e5d2a-7c41-4f0e-8d2b-3a9c1e7f6b54',
        slug: 'marlix',
        name: 'marlix',
        layersPath: 'assets/avatars/marlix/',
      },
      onboardingCompleted: false,
      dataConsentAt: null,
      settings: { remindersEnabled: false },
    });
  });

  const invalidBodies: [string, unknown, string][] = [
    ['no consent', { remindersEnabled: true }, 'dataConsent'],
    ['a refused consent', { dataConsent: false, remindersEnabled: true }, 'dataConsent'],
    ['a consent that is not a boolean', { dataConsent: 'yes', remindersEnabled: true }, 'dataConsent'],
    ['no answer to the reminders offer', { dataConsent: true }, 'remindersEnabled'],
    ['an unknown field', { dataConsent: true, remindersEnabled: true, plan: 'pro' }, 'body'],
  ];
  for (const [name, body, field] of invalidBodies) {
    it(`rejects ${name} and leaves onboarding open`, async () => {
      const response = await app.postJson('/v1/onboarding', body);
      assert.equal(response.status, 400);
      const error = ((await response.json()) as any).error;
      assert.equal(error.code, 'VALIDATION_ERROR');
      assert.ok(error.details.fields.some((f: { field: string }) => f.field === field));
      assert.equal(((await (await me()).json()) as any).onboardingCompleted, false);
    });
  }

  it('records the consent and the reminders answer, and marks onboarding as done', async () => {
    const before = Date.now();
    const response = await app.postJson('/v1/onboarding', { dataConsent: true, remindersEnabled: true });
    assert.equal(response.status, 200);

    const body = (await response.json()) as any;
    assert.equal(body.onboardingCompleted, true);
    assert.deepEqual(body.settings, { remindersEnabled: true });
    assert.ok(Date.parse(body.dataConsentAt) >= before - 1000);
    assert.deepEqual(await (await me()).json(), body);
  });

  it('is done once per account: the second call is a 409 and keeps the first answer', async () => {
    const response = await app.postJson('/v1/onboarding', { dataConsent: true, remindersEnabled: false });
    assert.equal(response.status, 409);
    assert.equal(((await response.json()) as any).error.code, 'ONBOARDING_ALREADY_COMPLETED');
    assert.deepEqual(profiles.get(USER)?.settings, { remindersEnabled: true });
  });
});
