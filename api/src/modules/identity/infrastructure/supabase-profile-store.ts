import type { SupabaseClient } from '@supabase/supabase-js';

import { databaseFailure } from '../../../shared/infrastructure/persistence/database-error.js';
import type { Profile, VoiceConfig } from '../domain/profile.js';
import { OnboardingAlreadyCompletedError, type ProfileStore } from '../application/profile-store.js';

interface ProfileRow {
  id: string;
  plan: string;
  data_consent_at: string | null;
  onboarding_completed_at: string | null;
  reminders_enabled: boolean;
  avatar: { id: string; slug: string; name: string; layers_path: string; voice_config: VoiceConfig };
}

const COLUMNS =
  'id, plan, data_consent_at, onboarding_completed_at, reminders_enabled, avatar:avatars(id, slug, name, layers_path, voice_config)';

/** The service key bypasses RLS, so every profile query must be scoped. */
export function createSupabaseProfileStore(client: SupabaseClient): ProfileStore {
  async function get(userId: string): Promise<Profile | undefined> {
    const { data, error } = await client
      .from('users')
      .select(COLUMNS)
      .eq('id', userId)
      .maybeSingle<ProfileRow>();
    if (error) throw databaseFailure('Reading the profile', error);
    return data ? toProfile(data) : undefined;
  }

  return {
    get,

    async completeOnboarding(userId, remindersEnabled) {
      const now = new Date().toISOString();
      // The update predicate prevents two requests from completing onboarding.
      const { data, error } = await client
        .from('users')
        .update({
          data_consent_at: now,
          onboarding_completed_at: now,
          reminders_enabled: remindersEnabled,
        })
        .eq('id', userId)
        .is('onboarding_completed_at', null)
        .select('id');
      if (error) throw databaseFailure('Completing onboarding', error);
      if (data.length === 0) throw new OnboardingAlreadyCompletedError();

      const profile = await get(userId);
      if (!profile) throw databaseFailure('Completing onboarding');
      return profile;
    },
  };
}

function toProfile(row: ProfileRow): Profile {
  return {
    id: row.id,
    plan: row.plan,
    avatar: {
      id: row.avatar.id,
      slug: row.avatar.slug,
      name: row.avatar.name,
      layersPath: row.avatar.layers_path,
      voiceConfig: row.avatar.voice_config,
    },
    onboardingCompleted: row.onboarding_completed_at !== null,
    dataConsentAt: row.data_consent_at,
    settings: { remindersEnabled: row.reminders_enabled },
  };
}
