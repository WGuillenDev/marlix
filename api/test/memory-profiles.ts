import {
  OnboardingAlreadyCompletedError,
  type Profile,
  type ProfileStore,
} from '../src/services/profile/profile-store.js';

const MARLIX = {
  id: '0b8e5d2a-7c41-4f0e-8d2b-3a9c1e7f6b54',
  slug: 'marlix',
  name: 'marlix',
};

/** Profiles in memory: every user starts with onboarding still open. */
export function createFakeProfiles() {
  const profiles = new Map<string, Profile>();

  const store: ProfileStore = {
    async get(userId) {
      return profiles.get(userId) ?? fresh(userId);
    },
    async completeOnboarding(userId, remindersEnabled) {
      const current = profiles.get(userId) ?? fresh(userId);
      if (current.onboardingCompleted) throw new OnboardingAlreadyCompletedError();
      const done: Profile = {
        ...current,
        onboardingCompleted: true,
        dataConsentAt: new Date().toISOString(),
        settings: { remindersEnabled },
      };
      profiles.set(userId, done);
      return done;
    },
  };

  function fresh(userId: string): Profile {
    const profile: Profile = {
      id: userId,
      plan: 'personal',
      avatar: MARLIX,
      onboardingCompleted: false,
      dataConsentAt: null,
      settings: { remindersEnabled: false },
    };
    profiles.set(userId, profile);
    return profile;
  }

  return { store, profiles };
}
