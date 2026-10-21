import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/models/profile.dart';
import 'package:marlix/models/voice_config.dart';

Map<String, Object?> voiceJson() => {
  'engine': 'supertonic-3',
  'voice': 'F4',
  'language': 'es',
  'steps': 5,
  'rate': 1.05,
  'fallback': {'voice': 'default', 'pitch': 1.0, 'rate': 1},
};

Map<String, Object?> profileJson(Object? voiceConfig) => {
  'id': 'u1',
  'plan': 'personal',
  'avatar': {
    'id': 'a1',
    'slug': 'marlix',
    'name': 'marlix',
    'layersPath': 'assets/avatars/marlix/',
    'voiceConfig': ?voiceConfig,
  },
  'onboardingCompleted': true,
  'dataConsentAt': null,
  'settings': {'remindersEnabled': false},
};

void main() {
  group('VoiceConfig.tryParse', () {
    test('reads what the backend sends, whole numbers and decimals alike', () {
      final config = VoiceConfig.tryParse(voiceJson())!;

      expect(config.engine, VoiceEngineKind.supertonic);
      expect(config.voice, 'F4');
      expect(config.language, 'es');
      expect(config.steps, 5);
      expect(config.rate, 1.05);
      expect(config.fallback.rate, 1.0);
      expect(config.fallback.pitch, 1.0);
      expect(config, VoiceConfig.defaults, reason: 'the defaults are the S6-1 decision');
    });

    test('the native engine is understood', () {
      final config = VoiceConfig.tryParse({...voiceJson(), 'engine': 'native'})!;

      expect(config.engine, VoiceEngineKind.native);
    });

    test('a shape it does not understand gives null, never an exception', () {
      final bad = <Object?>[
        null,
        'F4',
        <String, Object?>{},
        {'voice': 'default', 'pitch': 1.0, 'rate': 1.0}, // the shape before S6-2
        {...voiceJson(), 'engine': 'cloud'},
        {...voiceJson(), 'steps': '5'},
        {...voiceJson(), 'steps': 0},
        {...voiceJson(), 'steps': 2.5},
        {...voiceJson(), 'fallback': 'default'},
        {...voiceJson(), 'rate': null},
      ];
      for (final json in bad) {
        expect(VoiceConfig.tryParse(json), isNull, reason: '$json');
      }
    });

    test('equal configurations are equal, so a reload does not restart the voice', () {
      expect(VoiceConfig.tryParse(voiceJson()), VoiceConfig.tryParse(voiceJson()));
      expect(
        VoiceConfig.tryParse(voiceJson()),
        isNot(VoiceConfig.tryParse({...voiceJson(), 'voice': 'F1'})),
      );
    });
  });

  group('Profile', () {
    test('carries the avatar voice from /v1/me', () {
      final profile = Profile.fromJson(profileJson(voiceJson()));

      expect(profile.avatarVoiceConfig, VoiceConfig.defaults);
    });

    test('an older backend that sends no voiceConfig still gives a profile', () {
      final profile = Profile.fromJson(profileJson(null));

      expect(profile.avatarVoiceConfig, isNull);
      expect(profile.avatarSlug, 'marlix');
    });

    test('a voiceConfig the app does not understand does not break the profile', () {
      final profile = Profile.fromJson(profileJson({'engine': 'quantum'}));

      expect(profile.avatarVoiceConfig, isNull);
      expect(profile.onboardingCompleted, isTrue);
    });
  });
}
