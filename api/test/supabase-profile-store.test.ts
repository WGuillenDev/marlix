import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { DatabaseError } from '../src/services/database-error.js';
import { OnboardingAlreadyCompletedError } from '../src/services/profile/profile-store.js';
import { createSupabaseProfileStore } from '../src/services/profile/supabase-profile-store.js';
import { fakeSupabaseClient } from './fake-supabase.js';
import { captureConsole } from './helpers.js';

const USER = '00000000-0000-4000-8000-00000000000a';
const VOICE = {
  engine: 'supertonic-3',
  voice: 'F4',
  language: 'es',
  steps: 5,
  rate: 1.05,
  fallback: { voice: 'default', pitch: 1.0, rate: 1.0 },
};
const ROW = {
  id: USER,
  plan: 'personal',
  data_consent_at: null,
  onboarding_completed_at: null,
  reminders_enabled: false,
  avatar: {
    id: 'a1',
    slug: 'marlix',
    name: 'marlix',
    layers_path: 'assets/avatars/marlix/',
    voice_config: VOICE,
  },
};

describe('createSupabaseProfileStore', () => {
  it('reads the profile of that user only, with its avatar', async () => {
    const { client, calls } = fakeSupabaseClient(() => ({ body: [ROW] }));
    const profile = await createSupabaseProfileStore(client).get(USER);

    assert.deepEqual(profile, {
      id: USER,
      plan: 'personal',
      avatar: {
        id: 'a1',
        slug: 'marlix',
        name: 'marlix',
        layersPath: 'assets/avatars/marlix/',
        voiceConfig: VOICE,
      },
      onboardingCompleted: false,
      dataConsentAt: null,
      settings: { remindersEnabled: false },
    });
    const query = calls[0]!.params;
    assert.equal(calls[0]!.table, 'users');
    assert.equal(query.get('id'), `eq.${USER}`);
    assert.match(query.get('select') ?? '', /avatar:avatars\(id,slug,name,layers_path,voice_config\)/);
  });

  it('says onboarding is done when onboarding_completed_at is set', async () => {
    const done = '2026-10-19T20:00:00Z';
    const { client } = fakeSupabaseClient(() => ({
      body: [{ ...ROW, data_consent_at: done, onboarding_completed_at: done }],
    }));
    const profile = await createSupabaseProfileStore(client).get(USER);

    assert.equal(profile?.onboardingCompleted, true);
    assert.equal(profile?.dataConsentAt, done);
  });

  it('returns undefined when the user has no profile row', async () => {
    const { client } = fakeSupabaseClient(() => ({ body: [] }));
    assert.equal(await createSupabaseProfileStore(client).get(USER), undefined);
  });

  it('completes onboarding only while it is still open, in one update', async () => {
    const done = '2026-10-19T20:00:00Z';
    const { client, calls } = fakeSupabaseClient((call) =>
      call.method === 'PATCH'
        ? { body: [{ id: USER }] }
        : { body: [{ ...ROW, onboarding_completed_at: done, reminders_enabled: true }] },
    );
    const profile = await createSupabaseProfileStore(client).completeOnboarding(USER, true);

    const update = calls[0]!;
    assert.equal(update.method, 'PATCH');
    assert.equal(update.params.get('id'), `eq.${USER}`);
    assert.equal(update.params.get('onboarding_completed_at'), 'is.null');
    const body = update.body as Record<string, unknown>;
    assert.equal(body.reminders_enabled, true);
    assert.equal(body.data_consent_at, body.onboarding_completed_at);
    assert.ok(!Number.isNaN(Date.parse(body.data_consent_at as string)));
    assert.equal(profile.onboardingCompleted, true);
  });

  it('fails with OnboardingAlreadyCompletedError when no row was open', async () => {
    const { client } = fakeSupabaseClient(() => ({ body: [] }));
    await assert.rejects(
      createSupabaseProfileStore(client).completeOnboarding(USER, false),
      OnboardingAlreadyCompletedError,
    );
  });

  it('fails with a DatabaseError that logs only the error code', async () => {
    const { client } = fakeSupabaseClient(() => ({
      status: 500,
      body: { code: '57P01', message: 'row quoted: me siento triste' },
    }));
    const { output } = await captureConsole(async () => {
      await assert.rejects(createSupabaseProfileStore(client).get(USER), DatabaseError);
    });

    assert.match(output, /57P01/);
    assert.doesNotMatch(output, /triste/);
  });
});
