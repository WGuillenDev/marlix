import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/microphone_permission.dart';
import '../../services/voice/speech_recognizer.dart';
import '../../services/voice/voice_providers.dart';
import '../chat/chat_controller.dart';
import '../chat/reply_reader.dart';

export '../../services/voice/speech_recognizer.dart' show SpeechFailure;

sealed class SpeechState {
  const SpeechState();
}

/// Not listening.
final class SpeechIdle extends SpeechState {
  const SpeechIdle();
}

/// The microphone is open; [heard] is what has been understood so far.
final class SpeechListening extends SpeechState {
  const SpeechListening([this.heard = '']);

  final String heard;
}

/// The person did not allow the microphone. When [blocked] the system will not
/// ask again, so the phone's settings are the only way.
final class SpeechDenied extends SpeechState {
  const SpeechDenied({required this.blocked});

  final bool blocked;
}

/// The recognizer could not understand the person; writing keeps working.
final class SpeechProblem extends SpeechState {
  const SpeechProblem(this.failure);

  final SpeechFailure failure;
}

/// The only way screens listen to the person (S6-8). What is understood goes
/// through the same `ChatController.send` as typed text, so the crisis filter of
/// `POST /chat` applies equally. Nothing here can break the text chat.
class SpeechController extends Notifier<SpeechState> {
  StreamSubscription<SpeechEvent>? _listening;

  @override
  SpeechState build() {
    final recognizer = ref.read(speechRecognizerProvider);
    ref.onDispose(() {
      unawaited(_listening?.cancel());
      unawaited(recognizer.cancel());
    });
    return const SpeechIdle();
  }

  SpeechRecognizer get _recognizer => ref.read(speechRecognizerProvider);

  bool get listening => state is SpeechListening;

  /// Opens the microphone, asking for the permission first if the person has
  /// not given it. marlix goes quiet so it does not hear itself.
  Future<void> listen() async {
    if (listening) return;
    final access = await ref.read(microphonePermissionProvider).ask();
    if (!ref.mounted) return;
    if (access != MicrophoneAccess.granted) {
      state = SpeechDenied(blocked: access == MicrophoneAccess.blocked);
      return;
    }

    await ref.read(replyReaderProvider.notifier).stop();
    if (!ref.mounted) return;
    state = const SpeechListening();
    await _listening?.cancel();
    _listening = _recognizer.listen().listen(
      _onEvent,
      onError: (Object error) {
        if (!ref.mounted) return;
        state = SpeechProblem(error is SpeechException ? error.failure : SpeechFailure.other);
      },
      onDone: () {
        // Ended without a result, such as cancelled: nothing is left open.
        if (ref.mounted && state is SpeechListening) state = const SpeechIdle();
      },
    );
  }

  void _onEvent(SpeechEvent event) {
    if (!ref.mounted) return;
    switch (event) {
      case SpeechPartial(:final text):
        state = SpeechListening(text);
      case SpeechFinal(:final text):
        state = const SpeechIdle();
        unawaited(ref.read(chatControllerProvider.notifier).send(text));
    }
  }

  /// The person is done talking: the recognizer gives what it understood.
  Future<void> finish() async {
    if (listening) await _recognizer.stop();
  }

  /// Closes the microphone and drops what was heard.
  Future<void> cancel() async {
    final listening = _listening;
    _listening = null;
    unawaited(listening?.cancel());
    state = const SpeechIdle();
    await _recognizer.cancel();
  }

  Future<void> openSettings() => ref.read(microphonePermissionProvider).openSettings();
}

final speechControllerProvider = NotifierProvider<SpeechController, SpeechState>(
  SpeechController.new,
);
