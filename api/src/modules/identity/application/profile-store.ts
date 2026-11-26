import type { Profile } from '../domain/profile.js';

export class OnboardingAlreadyCompletedError extends Error {
  constructor() {
    super('Onboarding was already completed');
    this.name = 'OnboardingAlreadyCompletedError';
  }
}

export interface ProfileStore {
  /** The profile of a signed-in user, or undefined if it has no profile row. */
  get(userId: string): Promise<Profile | undefined>;

  /** Saves consent and completes onboarding atomically. */
  completeOnboarding(userId: string, remindersEnabled: boolean): Promise<Profile>;
}
