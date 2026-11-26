import 'dart:async';
import 'dart:typed_data';

import '../domain/voice_frame.dart';

abstract interface class VoiceActivity {
  /// Emits one event per input frame, in order.
  Stream<VoiceFrame> get frames;

  static const frameSamples = voiceFrameSamples;

  Future<void> open();

  void feed(Uint8List pcm);

  void close();

  Future<void> dispose();
}
