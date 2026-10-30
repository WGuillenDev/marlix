import 'dart:typed_data';

/// What the microphone is read at, and what `POST /v1/transcribe` expects.
const speechSampleRate = 16000;

/// Wraps 16-bit mono PCM in the WAV header the backend checks (S6-9).
Uint8List pcm16ToWav(Uint8List pcm, {int sampleRate = speechSampleRate}) {
  final header = ByteData(44);
  void tag(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  return Uint8List(44 + pcm.length)
    ..setRange(0, 44, header.buffer.asUint8List())
    ..setRange(44, 44 + pcm.length, pcm);
}
