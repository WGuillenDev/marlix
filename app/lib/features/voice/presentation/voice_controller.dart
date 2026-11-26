import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/presentation/profile_controller.dart';
import '../application/voice_engine.dart' show VoiceEvent;
import '../application/voice_service.dart';
import '../composition/voice_providers.dart';
import '../domain/voice_config.dart';

export '../application/voice_engine.dart'
    show VoiceEvent, VoiceException, VoiceFinished, VoiceLevel, VoiceProgress, VoiceStarted;
export '../application/voice_service.dart';

/// Fall back to the bundled defaults until the profile's voice settings are available.
final voiceConfigProvider = Provider<VoiceConfig>(
  (ref) => ref.watch(profileControllerProvider).value?.avatarVoiceConfig ?? VoiceConfig.defaults,
);

class VoiceController extends Notifier<VoiceStatus> {
  late final VoiceService _service;

  @override
  VoiceStatus build() {
    _service = VoiceService(
      config: () => ref.read(voiceConfigProvider),
      facts: ref.read(deviceFactsProvider),
      memory: ref.read(voiceMemoryProvider),
      model: ref.read(voiceModelProvider),
      createSupertonic: ref.read(supertonicEngineFactoryProvider),
      createNative: ref.read(nativeEngineFactoryProvider),
      onStatus: (status) {
        if (ref.mounted) state = status;
      },
    );
    ref.onDispose(() => unawaited(_service.dispose()));
    ref.listen(voiceConfigProvider, (previous, next) {
      if (previous != next && state is! VoiceIdle) unawaited(start());
    });
    return const VoiceIdle();
  }

  Future<void> start() => _service.start();

  /// Mobile downloads require explicit consent.
  Future<void> download({bool allowMobileData = false}) =>
      _service.download(allowMobileData: allowMobileData);

  Stream<VoiceEvent> speak(String text) async* {
    if (state is VoiceIdle) await start();
    yield* _service.speak(text);
  }

  /// Starts speaking before the streamed reply is complete.
  Stream<VoiceEvent> speakSentences(Stream<String> sentences) async* {
    if (state is VoiceIdle) await start();
    yield* _service.speakSentences(sentences);
  }

  Future<void> pause() => _service.pause();

  Future<void> resume() => _service.resume();

  Future<void> stop() => _service.stop();
}

final voiceControllerProvider = NotifierProvider<VoiceController, VoiceStatus>(VoiceController.new);
