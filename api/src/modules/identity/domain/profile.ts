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
    layersPath: string;
    voiceConfig: VoiceConfig;
  };
  onboardingCompleted: boolean;
  dataConsentAt: string | null;
  settings: { remindersEnabled: boolean };
}
