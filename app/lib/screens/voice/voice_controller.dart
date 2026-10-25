import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/voice_config.dart';
import '../../services/voice/voice_engine.dart' show VoiceEvent;
import '../../services/voice/voice_providers.dart';
import '../../services/voice/voice_service.dart';
import '../onboarding/profile_controller.dart';

export '../../services/voice/voice_engine.dart'
    show VoiceEvent, VoiceException, VoiceFinished, VoiceProgress, VoiceStarted;
export '../../services/voice/voice_service.dart';

/// How the avatar speaks. The profile is loaded before the chat opens; while it
/// loads, or if the backend sends nothing the app understands, marlix's voice
/// from S6-1 applies.
final voiceConfigProvider = Provider<VoiceConfig>(
  (ref) => ref.watch(profileControllerProvider).value?.avatarVoiceConfig ?? VoiceConfig.defaults,
);

/// The only way screens make the avatar speak (S6-2). It chooses the engine for
/// the phone, so no screen imports one, and it keeps the state of the voice:
/// checking, downloading, ready, or why the native voice is used.
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
    // A new voice in the database takes effect without a new release.
    ref.listen(voiceConfigProvider, (previous, next) {
      if (previous != next && state is! VoiceIdle) unawaited(start());
    });
    return const VoiceIdle();
  }

  /// Checks the phone and prepares the voice. Calling it again starts over.
  Future<void> start() => _service.start();

  /// Downloads the model of the voice. Over mobile data only with
  /// [allowMobileData].
  Future<void> download({bool allowMobileData = false}) =>
      _service.download(allowMobileData: allowMobileData);

  /// Speaks [text]; the stream carries the start, the progress and the end.
  Stream<VoiceEvent> speak(String text) async* {
    if (state is VoiceIdle) await start();
    yield* _service.speak(text);
  }

  /// Holds the speech where it is; [resume] continues it.
  Future<void> pause() => _service.pause();

  Future<void> resume() => _service.resume();

  Future<void> stop() => _service.stop();
}

final voiceControllerProvider = NotifierProvider<VoiceController, VoiceStatus>(VoiceController.new);
