import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../models/voice_config.dart';
import 'voice_engine.dart';

/// The phone's own voice (`flutter_tts`): the fallback when Supertonic cannot
/// run. It is robust and weighs nothing, but it sounds less human.
class NativeVoiceEngine implements VoiceEngine {
  NativeVoiceEngine({required this.config, FlutterTts? tts, this.language = 'es'})
    : _tts = tts ?? FlutterTts();

  final NativeVoiceConfig config;
  final String language;
  final FlutterTts _tts;

  /// Costa Rican Spanish first, then the closest ones a phone usually has.
  static const preferredLocales = ['es-CR', 'es-419', 'es-MX', 'es-US', 'es-ES'];

  StreamController<VoiceEvent>? _active;
  var _text = '';
  var _length = 1;
  var _paused = false;

  @override
  VoiceEngineKind get kind => VoiceEngineKind.native;

  /// The Android speech rate: 0.5 is the normal pace, and the configuration
  /// says 1 for normal.
  static double androidRate(double configRate) => (configRate * 0.5).clamp(0.1, 1.0);

  /// The first locale of [language] the phone can speak, in order of
  /// preference, or null.
  static String? pickLocale(String language, Iterable<String> available) {
    for (final locale in _wanted(language)) {
      if (available.contains(locale)) return locale;
    }
    return null;
  }

  static List<String> _wanted(String language) => language == 'es' ? preferredLocales : [language];

  @override
  Future<void> prepare() async {
    final available = <String>[];
    for (final locale in _wanted(language)) {
      final answer = await _tts.isLanguageAvailable(locale);
      if (answer == 1 || answer == true) available.add(locale);
    }
    final locale = pickLocale(language, available);
    if (locale == null) throw const NoSpanishVoiceException();

    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(androidRate(config.rate));
    await _tts.setPitch(config.pitch);
    if (config.voice != 'default') await _selectVoice();
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() => _active?.add(const VoiceStarted(VoiceEngineKind.native)));
    _tts.setProgressHandler((text, start, end, word) {
      if (_length > 0) _active?.add(VoiceProgress((end / _length).clamp(0.0, 1.0)));
    });
    _tts.setCompletionHandler(() => _finish(done: true));
    // Pausing stops the speech on purpose; that is not the end of the sentence.
    _tts.setCancelHandler(() {
      if (!_paused) _finish(done: false);
    });
    _tts.setErrorHandler((message) {
      _active?.addError(VoiceException('Native voice failed: $message'));
      _finish(done: false);
    });
  }

  Future<void> _selectVoice() async {
    final voices = await _tts.getVoices;
    if (voices is! List) return;
    for (final voice in voices) {
      if (voice is Map && voice['name'] == config.voice) {
        await _tts.setVoice({'name': '${voice['name']}', 'locale': '${voice['locale']}'});
        return;
      }
    }
  }

  void _finish({required bool done}) {
    final active = _active;
    if (active == null) return;
    _active = null;
    if (done) active.add(const VoiceFinished());
    active.close();
  }

  @override
  Stream<VoiceEvent> speak(String text) {
    _finish(done: false);
    _paused = false;
    final controller = StreamController<VoiceEvent>();
    _active = controller;
    _text = text;
    _length = text.length;
    _say(controller);
    return controller.stream;
  }

  void _say(StreamController<VoiceEvent> controller) {
    _tts
        .speak(_text)
        .then<void>(
          (_) {},
          onError: (Object error) {
            if (_active == controller) {
              controller.addError(VoiceException('Native voice failed: $error'));
              _finish(done: false);
            }
          },
        );
  }

  @override
  Future<void> pause() async {
    if (_active == null || _paused) return;
    _paused = true;
    await _tts.stop();
  }

  @override
  Future<void> resume() async {
    final active = _active;
    if (!_paused) return;
    _paused = false;
    if (active != null) _say(active);
  }

  @override
  Future<void> stop() async {
    _paused = false;
    await _tts.stop();
    _finish(done: false);
  }

  @override
  Future<void> dispose() => stop();
}
