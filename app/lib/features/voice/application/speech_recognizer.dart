import 'dart:async';

sealed class SpeechEvent {
  const SpeechEvent();
}

/// Speech onset allows interruption before transcription is ready.
final class SpeechVoice extends SpeechEvent {
  const SpeechVoice();
}

final class SpeechUnderstanding extends SpeechEvent {
  const SpeechUnderstanding();
}

final class SpeechPartial extends SpeechEvent {
  const SpeechPartial(this.text);

  final String text;
}

final class SpeechFinal extends SpeechEvent {
  const SpeechFinal(this.text);

  final String text;
}

enum SpeechFailure { unavailable, noSpeech, busy, other }

class SpeechException implements Exception {
  const SpeechException(this.failure, [this.detail = '']);

  final SpeechFailure failure;
  final String detail;

  @override
  String toString() => 'SpeechException: ${failure.name} $detail'.trim();
}

abstract interface class SpeechRecognizer {
  /// Delay reopening the microphone until the previous turn closes.
  Duration get reopenDelay;

  /// Emits SpeechFinal after a pause or explicit stop. Cancel discards the result.
  /// The playback callback lets the recognizer distinguish speech from speaker echo.
  Stream<SpeechEvent> listen({Duration? silence, bool Function()? marlixSpeaking});

  Future<void> stop();

  Future<void> cancel();
}
