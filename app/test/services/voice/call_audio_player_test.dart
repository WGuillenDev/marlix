import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/services/voice/call_audio_player.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

class _FakePlayer implements AudioPlayer {
  final contexts = <AudioContext>[];
  var played = 0;

  @override
  Future<void> setAudioContext(AudioContext context) async => contexts.add(context);

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async => played++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _sound = TTSResult(
  audioData: Float64List.fromList([0, 0.1, -0.1]),
  sampleRate: 24000,
  duration: 0.001,
);

void main() {
  test('reading a reply in the chat plays as media, not through the call earpiece', () async {
    final fake = _FakePlayer();
    await CallAudioPlayer(player: fake, route: CallRoute()).play(_sound);

    expect(fake.contexts, [CallAudioPlayer.mediaContext]);
    expect(fake.played, 1);
  });

  test('with the microphone open it plays as a call, and goes back to media after', () async {
    final fake = _FakePlayer();
    final route = CallRoute();
    final player = CallAudioPlayer(player: fake, route: route);

    route.inCall = true;
    await player.play(_sound);
    await player.play(_sound);
    route.inCall = false;
    await player.play(_sound);

    expect(fake.contexts, [CallAudioPlayer.callContext, CallAudioPlayer.mediaContext]);
    expect(fake.played, 3);
  });
}
