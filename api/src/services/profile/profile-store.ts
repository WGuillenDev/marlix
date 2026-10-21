/**
 * How the app makes the avatar speak (S6-2). The database enforces this shape;
 * the app decides at run time whether the phone can use the engine or falls
 * back to its native voice.
 */
export interface VoiceConfig {
  engine: 'supertonic-3' | 'native';
  voice: string;
  language: string;
  steps: number;
  rate: number;
  fallback: { voice: string; pitch: number; rate: number };
}

export interface Profile {
  id: string;
  plan: string;
  avatar: {
    id: string;
    slug: string;
    name: string;
    /** Folder of the avatar's SVG layers in the app's assets (S5-7). */
    layersPath: string;
    voiceConfig: VoiceConfig;
  };
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
