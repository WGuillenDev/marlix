import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:marlix/services/voice/voice_activity.dart';

/// [ms] of constant audio whose loudness is [level] (0 to 1).
Uint8List pcmOf(int ms, double level) {
  final samples = 16 * ms;
  final data = ByteData(samples * 2);
  final value = (level * 32768).round();
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, value, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// A voice detector for tests: a frame louder than [threshold] is a voice. The
/// real model needs the phone, and what is under test is what comes after it.
class EnergyVoiceActivity implements VoiceActivity {
  EnergyVoiceActivity({this.threshold = 0.01});

  final double threshold;
  final _frames = StreamController<VoiceFrame>.broadcast(sync: true);
  final _waiting = BytesBuilder(copy: false);
  var opens = 0;
  var closes = 0;

  static const _frameBytes = VoiceActivity.frameSamples * 2;

  @override
  Stream<VoiceFrame> get frames => _frames.stream;

  @override
  Future<void> open() async => opens++;

  @override
  void feed(Uint8List pcm) {
    _waiting.add(pcm);
    final bytes = _waiting.takeBytes();
    var offset = 0;
    for (; offset + _frameBytes <= bytes.length; offset += _frameBytes) {
      final frame = Uint8List.fromList(bytes.sublist(offset, offset + _frameBytes));
      _frames.add(VoiceFrame(frame, _level(frame) > threshold ? 0.95 : 0.02));
    }
    if (offset < bytes.length) _waiting.add(bytes.sublist(offset));
  }

  @override
  void close() {
    closes++;
    _waiting.clear();
  }

  @override
  Future<void> dispose() => _frames.close();

  static double _level(Uint8List frame) {
    final data = frame.buffer.asByteData(frame.offsetInBytes, frame.length);
    var sum = 0.0;
    for (var i = 0; i < frame.length ~/ 2; i++) {
      final value = data.getInt16(i * 2, Endian.little) / 32768;
      sum += value * value;
    }
    return math.sqrt(sum / (frame.length ~/ 2));
  }
}
