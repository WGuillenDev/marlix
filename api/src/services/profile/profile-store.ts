export interface Profile {
  id: string;
  plan: string;
  avatar: { id: string; slug: string; name: string };
  onboardingCompleted: boolean;
  /** When the person gave the explicit data consent; null until they do. */
  dataConsentAt: string | null;
  settings: { remindersEnabled: boolean };
}

/** The person already finished onboarding; it is done once per account. */
export class OnboardingAlreadyCompletedError extends Error {
  constructor() {
    super('Onboarding was already completed');
    this.name = 'OnboardingAlreadyCompletedError';
  }
}

export interface ProfileStore {
  /** The profile of a signed-in user, or undefined if it has no profile row. */
  get(userId: string): Promise<Profile | undefined>;

  /**
   * Records the consent and the answer to the reminders offer, and marks
   * onboarding as done, in one step. Fails with OnboardingAlreadyCompletedError
   * if it was done before, even for two simultaneous calls.
   */
  completeOnboarding(userId: string, remindersEnabled: boolean): Promise<Profile>;
}
