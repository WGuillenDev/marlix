import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// What the recognizer hears while the person talks.
sealed class SpeechEvent {
  const SpeechEvent();
}

/// What has been understood so far; it changes as the person keeps talking.
final class SpeechPartial extends SpeechEvent {
  const SpeechPartial(this.text);

  final String text;
}

/// The recognizer is done and this is what it understood.
final class SpeechFinal extends SpeechEvent {
  const SpeechFinal(this.text);

  final String text;
}

enum SpeechFailure {
  /// The phone has no recognizer for the language, or it cannot start.
  unavailable,

  /// The microphone heard nothing that could be turned into words.
  noSpeech,

  /// Anything else, such as no connection when the phone needs one.
  other,
}

class SpeechException implements Exception {
  const SpeechException(this.failure, [this.detail = '']);

  final SpeechFailure failure;
  final String detail;

  @override
  String toString() => 'SpeechException: ${failure.name} $detail'.trim();
}

/// A way of understanding the person (S6-8). Screens never see one: they go
/// through `SpeechController`, so the recognizer behind it can change (Whisper in
/// Groq or inside the phone are the alternatives of the card) without touching them.
///
/// The microphone permission is not its business; `MicrophonePermission` asks it.
abstract interface class SpeechRecognizer {
  /// Starts listening. The stream ends after [SpeechFinal]; a failure comes as
  /// a [SpeechException] error, and [cancel] ends it without a result.
  Stream<SpeechEvent> listen();

  /// Stops listening and asks for the final result of what was heard.
  Future<void> stop();

  /// Stops listening and throws away what was heard.
  Future<void> cancel();
}

/// The recognizer of the phone (`speech_to_text`): free, and the same one of the
/// keyboard dictation, so it already understands Costa Rican Spanish.
class SpeechToTextRecognizer implements SpeechRecognizer {
  SpeechToTextRecognizer({SpeechToText? engine, this.language = 'es'})
    : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;
  final String language;

  /// Costa Rican Spanish first, then the closest ones a phone usually has.
  static const preferredLocales = ['es_CR', 'es_419', 'es_MX', 'es_US', 'es_ES'];

  /// How long one turn can last: a limit so a microphone left open ends.
  static const longest = Duration(seconds: 30);

  StreamController<SpeechEvent>? _active;

  /// The first locale of [language] the phone can recognize, in order of
  /// preference, or null. Android writes `es_CR` and iOS `es-CR`.
  static String? pickLocale(String language, Iterable<String> available) {
    final normalized = {for (final id in available) id.replaceAll('-', '_'): id};
    final wanted = language == 'es' ? preferredLocales : [language];
    for (final locale in wanted) {
      final id = normalized[locale];
      if (id != null) return id;
    }
    return null;
  }

  /// A phone error, as the failure the person is told about. `no_match` and
  /// `speech_timeout` are not breakages: nothing was said. `server_disconnected`
  /// is the recognizer restarting, so trying again works.
  static SpeechFailure failureOf(String message) => switch (message) {
    'error_no_match' || 'error_speech_timeout' => SpeechFailure.noSpeech,
    'error_language_unavailable' ||
    'error_language_not_supported' ||
    'error_permission' => SpeechFailure.unavailable,
    _ => SpeechFailure.other,
  };

  @override
  Stream<SpeechEvent> listen() {
    _close();
    final controller = StreamController<SpeechEvent>();
    _active = controller;
    unawaited(_start(controller));
    return controller.stream;
  }

  Future<void> _start(StreamController<SpeechEvent> controller) async {
    try {
      final ready = await _engine.initialize(onError: _onError);
      if (_active != controller) return;
      if (!ready) throw const SpeechException(SpeechFailure.unavailable, 'initialize failed');

      final locale = pickLocale(language, [
        for (final locale in await _engine.locales()) locale.localeId,
      ]);
      if (_active != controller) return;
      if (locale == null) throw const SpeechException(SpeechFailure.unavailable, 'no Spanish');

      await _engine.listen(
        onResult: (result) {
          if (_active != controller) return;
          final text = result.recognizedWords.trim();
          if (!result.finalResult) {
            if (text.isNotEmpty) controller.add(SpeechPartial(text));
            return;
          }
          if (text.isEmpty) {
            controller.addError(const SpeechException(SpeechFailure.noSpeech));
          } else {
            controller.add(SpeechFinal(text));
          }
          _close();
        },
        listenOptions: SpeechListenOptions(
          localeId: locale,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          // A preference: the phone falls back to its service when the language
          // is not downloaded, and this keeps the audio on the phone when it can.
          onDevice: true,
          listenFor: longest,
        ),
      );
    } on SpeechException catch (error) {
      _fail(controller, error);
    } on Object catch (error) {
      _fail(controller, SpeechException(SpeechFailure.other, '$error'));
    }
  }

  void _onError(SpeechRecognitionError error) {
    final controller = _active;
    if (controller == null) return;
    _fail(controller, SpeechException(failureOf(error.errorMsg), error.errorMsg));
  }

  void _fail(StreamController<SpeechEvent> controller, SpeechException error) {
    if (_active != controller) return;
    controller.addError(error);
    _close();
  }

  void _close() {
    final active = _active;
    _active = null;
    if (active != null && !active.isClosed) unawaited(active.close());
  }

  @override
  Future<void> stop() => _engine.stop();

  @override
  Future<void> cancel() async {
    _close();
    await _engine.cancel();
  }
}
