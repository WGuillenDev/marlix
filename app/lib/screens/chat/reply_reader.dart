import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/read_aloud.dart';
import '../voice/voice_controller.dart';
import 'avatar_controller.dart';
import 'chat_controller.dart';

/// [preparing] is the wait between asking for the reading and its first sound.
enum Reading { idle, preparing, speaking, paused }

/// Reads each reply that arrives while [repliesAreSpokenProvider] is on, and holds
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

  /// The sound of the current reading has begun, so the avatar has a mouth to
  /// move; a pause before that leaves nothing to resume on screen.
  var _soundStarted = false;

  /// The reply of the turn that is being answered is already being read as it
  /// arrives (S6-10), so it is not read again when it is complete.
  var _readLive = false;

  @override
  Reading build() {
    ref.onDispose(() => unawaited(_reading?.cancel()));
    ref.listen(liveReplyProvider, (_, sentences) {
      if (sentences == null) return;
      _readLive = true;
      unawaited(_start((voice) => voice.speakSentences(sentences)));
    });
    ref.listen(chatControllerProvider, (previous, next) {
      if (!(previous?.sending ?? false) || next.sending) return;
      if (_readLive) {
        _readLive = false;
        return;
      }
      final last = next.entries.lastOrNull;
      // A crisis reply stays on screen with its numbers and is not read.
      if (last is MarlixEntry && ref.read(repliesAreSpokenProvider)) {
        unawaited(read(last.message.content));
      }
    });
    ref.listen(signedInUserProvider, (_, _) => unawaited(stop()));
    ref.listen(repliesAreSpokenProvider, (_, on) {
      if (!on) unawaited(stop());
    });
    return Reading.idle;
  }

  VoiceController get _voice => ref.read(voiceControllerProvider.notifier);

  AvatarController get _avatar => ref.read(avatarStateProvider.notifier);

  void _onEvent(VoiceEvent event) {
    switch (event) {
      case VoiceStarted():
        _soundStarted = true;
        if (state == Reading.preparing) state = Reading.speaking;
        if (state == Reading.speaking) _avatar.speak();
      case VoiceLevel(:final level):
        if (state == Reading.speaking) ref.read(avatarVolumeProvider.notifier).set(level);
      case VoiceProgress() || VoiceFinished():
        break;
    }
  }

  /// Reads [text], cutting whatever was being read.
  Future<void> read(String text) => _start((voice) => voice.speak(text));

  Future<void> _start(Stream<VoiceEvent> Function(VoiceController voice) speak) async {
    await _reading?.cancel();
    _pausedByApp = false;
    _soundStarted = false;
    state = Reading.preparing;
    late final StreamSubscription<VoiceEvent> reading;
    void end() {
      if (_reading == reading && ref.mounted) {
        _reading = null;
        state = Reading.idle;
        _avatar.rest();
      }
    }

    reading = speak(_voice).listen(_onEvent, onError: (Object _) => end(), onDone: end);
    _reading = reading;
  }

  Future<void> pause({bool byApp = false}) async {
    if (state != Reading.speaking && state != Reading.preparing) return;
    state = Reading.paused;
    _pausedByApp = byApp;
    _avatar.rest();
    await _safely(_voice.pause);
  }

  Future<void> resume() async {
    if (state != Reading.paused) return;
    state = _soundStarted ? Reading.speaking : Reading.preparing;
    _pausedByApp = false;
    if (_soundStarted) _avatar.speak();
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
    _avatar.rest();
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
