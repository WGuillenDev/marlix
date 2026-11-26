import 'package:audioplayers/audioplayers.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

class CallRoute {
  bool inCall = false;
}

/// Use the speakerphone route during a call so capture can cancel playback echo.
/// Outside a call, use media routing to avoid the quiet earpiece.
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
    // Set routing on this player. Global changes only affect newly created players.
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
