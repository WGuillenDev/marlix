import 'package:audioplayers/audioplayers.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

/// Plays marlix's voice the way a call on speaker does (S6-9), so the phone's
/// echo canceller, which takes what the call plays as its reference, removes it
/// from the microphone. Played as plain media, the voice came back into the
/// microphone as loud as a person and marlix interrupted and answered itself.
///
/// The package's own player cannot be told how to play, so this one takes its
/// place.
class CallAudioPlayer implements TTSAudioPlayer {
  CallAudioPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Future<void>? _configured;
  var _disposed = false;

  static final context = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: true,
      audioMode: AndroidAudioMode.inCommunication,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.voiceCommunication,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {AVAudioSessionOptions.defaultToSpeaker},
    ),
  );

  @override
  Future<void> play(TTSResult result) async {
    if (_disposed) throw StateError('CallAudioPlayer has been disposed');
    // Set on this player before its first sound: a global context only reaches
    // the players created after it.
    await (_configured ??= _player.setAudioContext(context));
    await _player.play(BytesSource(result.toWavBytes()));
  }

  @override
  Future<void> stop() async {
    if (!_disposed) await _player.stop();
  }

  @override
  Future<void> pause() async {
    if (!_disposed) await _player.pause();
  }

  @override
  Future<void> resume() async {
    if (!_disposed) await _player.resume();
  }

  @override
  PlayerState get playerState => _player.state;

  @override
  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;

  @override
  bool get isPlaying => _player.state == PlayerState.playing;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _player.dispose();
  }
}
