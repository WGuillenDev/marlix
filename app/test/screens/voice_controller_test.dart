import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/models/profile.dart';
import 'package:marlix/models/voice_config.dart';
import 'package:marlix/screens/onboarding/profile_controller.dart';
import 'package:marlix/screens/voice/voice_controller.dart';
import 'package:marlix/services/help_resources.dart';
import 'package:marlix/services/voice/voice_planner.dart';
import 'package:marlix/services/voice/voice_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/voice/voice_fakes.dart';

Profile profileWith(VoiceConfig? config) => Profile(
  id: 'user-ana',
  avatarSlug: 'marlix',
  avatarVoiceConfig: config,
  onboardingCompleted: true,
  remindersEnabled: false,
);

class _FixedProfile extends ProfileController {
  _FixedProfile(this._profile);

  final Profile _profile;

  @override
  Future<Profile> build() async => _profile;
}

class _Voice extends Notifier<VoiceConfig> {
  @override
  VoiceConfig build() => VoiceConfig.defaults;

  void change(VoiceConfig config) => state = config;
}

final _voiceProvider = NotifierProvider<_Voice, VoiceConfig>(_Voice.new);

/// Waits until the voice finishes checking the phone.
Future<void> settled(ProviderContainer container) async {
  do {
    await pumpEventQueue();
  } while (container.read(voiceControllerProvider) is VoiceChecking);
}

void main() {
  late FakeFacts facts;
  late FakeModel model;
  late List<FakeEngine> supertonics;
  late List<VoiceConfig> configsUsed;

  Future<ProviderContainer> container({List<Override> extra = const []}) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    facts = FakeFacts();
    model = FakeModel(ready: true);
    supertonics = [];
    configsUsed = [];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        deviceFactsProvider.overrideWithValue(facts),
        voiceModelProvider.overrideWithValue(model),
        supertonicEngineFactoryProvider.overrideWithValue((config) {
          configsUsed.add(config);
          return FakeEngine(VoiceEngineKind.supertonic)..also(supertonics.add);
        }),
        nativeEngineFactoryProvider.overrideWithValue(
          (config) => FakeEngine(VoiceEngineKind.native),
        ),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('voiceConfigProvider', () {
    test('uses the avatar voice the backend sent', () async {
      const custom = VoiceConfig(
        engine: VoiceEngineKind.supertonic,
        voice: 'F1',
        language: 'es',
        steps: 3,
        rate: 1,
        fallback: NativeVoiceConfig(voice: 'default', pitch: 1, rate: 1),
      );
      final c = await container(
        extra: [profileControllerProvider.overrideWith(() => _FixedProfile(profileWith(custom)))],
      );
      await c.read(profileControllerProvider.future);

      expect(c.read(voiceConfigProvider), custom);
    });

    test('uses marlix voice while the profile loads, without one, or when it failed', () async {
      final c = await container(
        extra: [profileControllerProvider.overrideWith(() => _FixedProfile(profileWith(null)))],
      );

      expect(c.read(voiceConfigProvider), VoiceConfig.defaults, reason: 'still loading');
      await c.read(profileControllerProvider.future);
      expect(c.read(voiceConfigProvider), VoiceConfig.defaults, reason: 'the backend sent none');
    });
  });

  group('VoiceController', () {
    test('starts idle and checks the phone only when asked', () async {
      final c = await container();

      expect(c.read(voiceControllerProvider), isA<VoiceIdle>());
      expect(supertonics, isEmpty);

      await c.read(voiceControllerProvider.notifier).start();
      expect(
        c.read(voiceControllerProvider),
        isA<VoiceReady>().having((s) => s.engine, 'engine', VoiceEngineKind.supertonic),
      );
    });

    test('speaking before starting starts first, so no screen has to remember to', () async {
      final c = await container();

      final events = await c.read(voiceControllerProvider.notifier).speak('Hola.').toList();

      expect(events.last, isA<VoiceFinished>());
      expect(supertonics.single.spoken, ['Hola.']);
    });

    test('the screens see why the native voice is used', () async {
      final c = await container();
      facts.lowRam = true;

      await c.read(voiceControllerProvider.notifier).start();

      expect(
        c.read(voiceControllerProvider),
        isA<VoiceReady>()
            .having((s) => s.engine, 'engine', VoiceEngineKind.native)
            .having((s) => s.reason, 'reason', NativeReason.lowRam),
      );
    });

    test('a new voice in the database takes effect without a new release', () async {
      final c = await container(
        extra: [voiceConfigProvider.overrideWith((ref) => ref.watch(_voiceProvider))],
      );
      final controller = c.read(voiceControllerProvider.notifier);
      await controller.start();
      expect(configsUsed.single.voice, 'F4');

      c
          .read(_voiceProvider.notifier)
          .change(
            VoiceConfig(
              engine: VoiceEngineKind.supertonic,
              voice: 'F1',
              language: 'es',
              steps: 5,
              rate: 1.05,
              fallback: VoiceConfig.defaults.fallback,
            ),
          );
      await settled(c);

      expect(configsUsed.map((config) => config.voice), ['F4', 'F1']);
      expect(supertonics.first.disposed, isTrue);
    });

    test('a voice that is idle does not wake up when the configuration changes', () async {
      final c = await container(
        extra: [voiceConfigProvider.overrideWith((ref) => ref.watch(_voiceProvider))],
      );
      c.read(voiceControllerProvider);

      c
          .read(_voiceProvider.notifier)
          .change(
            VoiceConfig(
              engine: VoiceEngineKind.native,
              voice: 'default',
              language: 'es',
              steps: 5,
              rate: 1,
              fallback: VoiceConfig.defaults.fallback,
            ),
          );
      await pumpEventQueue();

      expect(supertonics, isEmpty);
      expect(c.read(voiceControllerProvider), isA<VoiceIdle>());
    });

    test('downloads the model when the person says so and then speaks with Supertonic', () async {
      final c = await container();
      model.ready = false;
      final controller = c.read(voiceControllerProvider.notifier);
      await controller.start();
      expect(c.read(voiceControllerProvider), isA<VoiceNeedsDownload>());

      await controller.download();

      expect(model.downloads, 1);
      expect(c.read(voiceControllerProvider), isA<VoiceReady>());
    });
  });
}

extension<T> on T {
  T also(void Function(T value) block) {
    block(this);
    return this;
  }
}
