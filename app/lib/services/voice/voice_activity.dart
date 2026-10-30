import 'dart:async';
import 'dart:typed_data';

import 'package:vad_plus/vad_plus.dart';

/// 32 ms of microphone audio (16 kHz mono 16-bit PCM) and how likely it is that
/// a person is speaking in it (S6-9).
class VoiceFrame {
  const VoiceFrame(this.pcm, this.probability);

  final Uint8List pcm;

  /// From 0 (no voice) to 1 (surely a voice).
  final double probability;
}

/// Tells, frame by frame, whether the microphone hears a voice. It looks at the
/// shape of the sound and not at how loud it is, so a quiet voice after the
/// phone's noise suppression still counts and a door or a fan does not.
abstract interface class VoiceActivity {
  /// One event per [frameSamples] fed, in order.
  Stream<VoiceFrame> get frames;

  static const frameSamples = 512;

  /// Gets the model ready and forgets what a previous listen left in it.
  Future<void> open();

  /// Audio of any length.
  void feed(Uint8List pcm);

  /// Forgets what was fed and drops the audio that is still waiting.
  void close();

  Future<void> dispose();
}

/// Silero VAD, run on the phone through `vad_plus`. It is only fed audio: the
/// microphone is the one in [AudioCapture], which has the echo cancellation on.
class SileroVoiceActivity implements VoiceActivity {
  final _frames = StreamController<VoiceFrame>.broadcast();
  VadPlus? _vad;
  StreamSubscription<VadEvent>? _events;
  Future<void>? _opening;

  /// The odd byte of a chunk, which belongs to the first sample of the next one.
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
