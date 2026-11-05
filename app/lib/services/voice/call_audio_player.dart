import 'package:audioplayers/audioplayers.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

/// Whether the microphone is open next to marlix's voice (the voice mode). Set
/// by the conversation, read by [CallAudioPlayer] each time it plays.
class CallRoute {
  bool inCall = false;
}

/// Plays marlix's voice the way a call on speaker does while the microphone is
/// open (S6-9), so the phone's echo canceller, which takes what the call plays
/// as its reference, removes it from the microphone. Played as plain media, the
/// voice came back into the microphone as loud as a person and marlix
/// interrupted and answered itself.
///
/// Without the microphone (reading a reply in the chat) it plays as media. The
/// call route sent it to the earpiece at the top of the phone, very quiet
/// (S7-13).
///
/// The package's own player cannot be told how to play, so this one takes its
/// place.
class CallAudioPlayer implements TTSAudioPlayer {
  CallAudioPlayer({AudioPlayer? player, CallRoute? route})
    : _player = player ?? AudioPlayer(),
      _route = route ?? CallRoute();

  final AudioPlayer _player;
  final CallRoute _route;
  bool? _inCall;
  var _disposed = false;

  static final callContext = AudioContext(
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

  static final mediaContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      audioMode: AndroidAudioMode.normal,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
  );

  @override
  Future<void> play(TTSResult result) async {
    if (_disposed) throw StateError('CallAudioPlayer has been disposed');
    // Set on this player before its sound: a global context only reaches the
    // players created after it. Set again only when the route changes.
    final inCall = _route.inCall;
    if (_inCall != inCall) {
      await _player.setAudioContext(inCall ? callContext : mediaContext);
      _inCall = inCall;
    }
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
