import 'dart:async';
import 'dart:typed_data';

import 'package:vad_plus/vad_plus.dart';

import '../application/voice_activity.dart';
import '../domain/voice_frame.dart';

class SileroVoiceActivity implements VoiceActivity {
  final _frames = StreamController<VoiceFrame>.broadcast();
  VadPlus? _vad;
  StreamSubscription<VadEvent>? _events;
  Future<void>? _opening;

  // Preserve a trailing byte so samples remain aligned across chunks.
  int? _carry;

  @override
  Stream<VoiceFrame> get frames => _frames.stream;

  @override
  Future<void> open() async {
    await (_opening ??= _initialize());
    _vad?.reset();
    _carry = null;
  }

  Future<void> _initialize() async {
    final vad = VadPlus();
    _events = vad.events.listen((event) {
      if (event is VadFrameProcessed) {
        _frames.add(VoiceFrame(_toPcm(event.audioData), event.probability));
      }
    });
    try {
      await vad.initialize();
    } on Object {
      await _events?.cancel();
      _opening = null;
      vad.dispose();
      rethrow;
    }
    _vad = vad;
  }

  @override
  void feed(Uint8List pcm) {
    final vad = _vad;
    if (vad == null) return;
    var bytes = pcm;
    final carry = _carry;
    if (carry != null) {
      bytes = Uint8List(pcm.length + 1)
        ..[0] = carry
        ..setRange(1, pcm.length + 1, pcm);
      _carry = null;
    }
    if (bytes.length.isOdd) {
      _carry = bytes.last;
      bytes = Uint8List.sublistView(bytes, 0, bytes.length - 1);
    }
    if (bytes.isEmpty) return;
    vad.processAudio(_toFloats(bytes));
  }

  @override
  void close() {
    _vad?.reset();
    _carry = null;
  }

  @override
  Future<void> dispose() async {
    await _events?.cancel();
    _vad?.dispose();
    _vad = null;
    _opening = null;
    await _frames.close();
  }

  static Float32List _toFloats(Uint8List pcm) {
    final data = pcm.buffer.asByteData(pcm.offsetInBytes, pcm.length);
    final out = Float32List(pcm.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768;
    }
    return out;
  }

  static Uint8List _toPcm(Float32List samples) {
    final data = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(i * 2, (samples[i] * 32768).round().clamp(-32768, 32767), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
