import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/services/voice/wav.dart';

void main() {
  test('wraps the PCM in the 16 kHz mono 16-bit header the backend checks', () {
    final pcm = Uint8List.fromList([1, 2, 3, 4, 5, 6]);

    final wav = pcm16ToWav(pcm);
    final header = ByteData.sublistView(wav);

    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(wav.sublist(8, 16)), 'WAVEfmt ');
    expect(ascii.decode(wav.sublist(36, 40)), 'data');
    expect(header.getUint32(4, Endian.little), 36 + pcm.length);
    expect(header.getUint16(20, Endian.little), 1, reason: 'PCM');
    expect(header.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint32(28, Endian.little), 32000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), pcm.length);
    expect(wav.length, 44 + pcm.length);
    expect(wav.sublist(44), pcm);
  });
}
