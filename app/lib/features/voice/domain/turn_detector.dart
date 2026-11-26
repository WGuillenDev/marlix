import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'voice_frame.dart';
import 'wav.dart';

sealed class TurnEvent {
  const TurnEvent();
}

final class TurnStarted extends TurnEvent {
  const TurnStarted();
}

/// PCM includes pre-roll so the first syllable is not clipped.
final class TurnEnded extends TurnEvent {
  const TurnEnded(this.pcm);

  final Uint8List pcm;
}

/// A false start resets the detector without producing a turn.
final class TurnDropped extends TurnEvent {
  const TurnDropped();
}

/// Detect turn boundaries from voice probability and signal level.
class TurnDetector {
  TurnDetector({
    this.silence = const Duration(milliseconds: 800),
    this.minSpeech = const Duration(milliseconds: 300),
    this.preRoll = const Duration(milliseconds: 400),
    this.longest = const Duration(seconds: 30),
  });

  final Duration silence;

  // Require sustained evidence to avoid starting on transient noise.
  final Duration minSpeech;
  final Duration preRoll;
  final Duration longest;

  static const frameSamples = voiceFrameSamples;
  static const frameMs = frameSamples * 1000 ~/ speechSampleRate;

  // Use a lower threshold during speech so quiet syllables do not end the turn.
  static const startProbability = 0.75;
  static const keepProbability = 0.45;

  // Reject low-volume background speech even when the detector reports a voice.
  static const startLoudness = 0.035;

  // Playback increases the likelihood of echo being classified as speech.
  static const minVoiceShare = 0.5;

  static const guardProbability = 0.85;
  static const guardLoudness = 0.06;
  static const guardDuration = 1.3;

  final _before = Queue<Uint8List>();
  final _turn = BytesBuilder(copy: false);

  var _speaking = false;
  var _voiceFrames = 0;
  var _quietFrames = 0;
  var _turnFrames = 0;
  var _voicedFrames = 0;
  var _activeFrames = 0;

  bool guarded = false;

  bool get speaking => _speaking;

  List<TurnEvent> add(VoiceFrame frame) {
    final events = <TurnEvent>[];

    if (!_speaking) {
      final voice = guarded
          ? frame.probability > guardProbability && _loudness(frame.pcm) > guardLoudness
          : frame.probability > startProbability && _loudness(frame.pcm) > startLoudness;
      // Allow a brief uncertain frame without discarding accumulated speech evidence.
      _voiceFrames = voice ? _voiceFrames + 1 : math.max(0, _voiceFrames - 1);
      _before.addLast(frame.pcm);
      final keep = (preRoll + minSpeech).inMilliseconds ~/ frameMs;
      while (_before.length > keep) {
        _before.removeFirst();
      }
      final needed = (minSpeech.inMilliseconds * (guarded ? guardDuration : 1.0)) / frameMs;
      if (_voiceFrames >= needed) {
        _speaking = true;
        _quietFrames = 0;
        _before.forEach(_turn.add);
        _turnFrames = _before.length;
        // Only include confirmed speech in the minimum voiced duration.
        _activeFrames = _voiceFrames;
        _voicedFrames = _voiceFrames;
        _before.clear();
        events.add(const TurnStarted());
      }
      return events;
    }

    _turn.add(frame.pcm);
    _turnFrames++;
    _activeFrames++;
    if (frame.probability > keepProbability) {
      _voicedFrames++;
      _quietFrames = 0;
    } else {
      _quietFrames++;
    }
    final silent = _quietFrames * frameMs >= silence.inMilliseconds;
    final tooLong = _turnFrames * frameMs >= longest.inMilliseconds;
    if (silent || tooLong) {
      events.add(_end());
      _reset();
    }
    return events;
  }

  List<TurnEvent> flush() {
    final events = <TurnEvent>[];
    if (_speaking) events.add(_end());
    _reset();
    return events;
  }

  void _reset() {
    _before.clear();
    _turn.clear();
    _speaking = false;
    _voiceFrames = 0;
    _quietFrames = 0;
    _turnFrames = 0;
    _voicedFrames = 0;
    _activeFrames = 0;
  }

  // Exclude the terminating silence from audio sent for transcription.
  TurnEvent _end() {
    final said = _activeFrames - _quietFrames;
    final pcm = _turn.takeBytes();
    return said > 0 && _voicedFrames / said >= minVoiceShare ? TurnEnded(pcm) : const TurnDropped();
  }

  static double _loudness(Uint8List frame) {
    final samples = frame.buffer.asByteData(frame.offsetInBytes, frame.length);
    final count = frame.length ~/ 2;
    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      final value = samples.getInt16(i * 2, Endian.little) / 32768;
      sum += value * value;
    }
    return count == 0 ? 0 : math.sqrt(sum / count);
  }
}
