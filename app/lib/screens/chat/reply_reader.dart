import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/read_aloud.dart';
import '../voice/voice_controller.dart';
import 'chat_controller.dart';

enum Reading { idle, speaking, paused }

/// Reads each reply that arrives while [readAloudProvider] is on, and holds
/// what the chat screen needs to show the controls.
///
/// Voice never breaks the text chat: the reply is already on screen when it
/// starts, and every voice failure only ends the reading.
class ReplyReader extends Notifier<Reading> {
  StreamSubscription<VoiceEvent>? _reading;

  /// The app paused the reading because it went to the background, so it
  /// continues by itself when the person comes back. A pause by the person
  /// stays until they resume.
  var _pausedByApp = false;

  @override
  Reading build() {
    ref.onDispose(() => unawaited(_reading?.cancel()));
    ref.listen(chatControllerProvider, (previous, next) {
      if (!(previous?.sending ?? false) || next.sending) return;
      final last = next.entries.lastOrNull;
      // A crisis reply stays on screen with its numbers and is not read.
      if (last is MarlixEntry && ref.read(readAloudProvider)) {
        unawaited(read(last.message.content));
      }
    });
    ref.listen(signedInUserProvider, (_, _) => unawaited(stop()));
    ref.listen(readAloudProvider, (_, on) {
      if (!on) unawaited(stop());
    });
    return Reading.idle;
  }

  VoiceController get _voice => ref.read(voiceControllerProvider.notifier);

  /// Reads [text], cutting whatever was being read.
  Future<void> read(String text) async {
    await _reading?.cancel();
    _pausedByApp = false;
    state = Reading.speaking;
    late final StreamSubscription<VoiceEvent> reading;
    void end() {
      if (_reading == reading && ref.mounted) {
        _reading = null;
        state = Reading.idle;
      }
    }

    reading = _voice.speak(text).listen((_) {}, onError: (Object _) => end(), onDone: end);
    _reading = reading;
  }

  Future<void> pause({bool byApp = false}) async {
    if (state != Reading.speaking) return;
    state = Reading.paused;
    _pausedByApp = byApp;
    await _safely(_voice.pause);
  }

  Future<void> resume() async {
    if (state != Reading.paused) return;
    state = Reading.speaking;
    _pausedByApp = false;
    await _safely(_voice.resume);
  }

  /// The person is back in the app: continue only what the app paused.
  Future<void> resumeAfterBackground() async {
    if (_pausedByApp) await resume();
  }

  Future<void> stop() async {
    final reading = _reading;
    if (reading == null && state == Reading.idle) return;
    _reading = null;
    _pausedByApp = false;
    state = Reading.idle;
    await _safely(_voice.stop);
    await reading?.cancel();
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // The text chat does not depend on the voice.
    }
  }
}

final replyReaderProvider = NotifierProvider<ReplyReader, Reading>(ReplyReader.new);
