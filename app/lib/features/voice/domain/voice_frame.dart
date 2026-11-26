import 'dart:typed_data';

/// A 32 ms microphone frame with PCM samples and speech probability.
class VoiceFrame {
  const VoiceFrame(this.pcm, this.probability);

  final Uint8List pcm;

  final double probability;
}

const voiceFrameSamples = 512;
