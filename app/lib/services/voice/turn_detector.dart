import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'voice_activity.dart';
import 'wav.dart';

/// What the detector finds in the microphone audio (S6-9).
sealed class TurnEvent {
  const TurnEvent();
}

/// The person started to speak: long enough not to be a click or a cough.
final class TurnStarted extends TurnEvent {
  const TurnStarted();
}

/// The person stopped speaking. [pcm] is the whole turn, from a moment before
/// the first word, as 16 kHz mono 16-bit PCM.
final class TurnEnded extends TurnEvent {
  const TurnEnded(this.pcm);

  final Uint8List pcm;
}

/// A turn that began but was not speech after all: noise that kept looking like
/// a voice for an instant now and then.
final class TurnDropped extends TurnEvent {
  const TurnDropped();
}

/// Decides when a person begins and ends a turn from the probability of voice
/// that [VoiceActivity] gives for each frame.
///
/// It keeps a little audio from before the voice was confirmed, so the first
/// syllable is not lost, and it ends the turn only after a silence, so a pause
/// to think does not cut the person.
class TurnDetector {
  TurnDetector({
    this.silence = const Duration(milliseconds: 800),
    this.minSpeech = const Duration(milliseconds: 300),
    this.preRoll = const Duration(milliseconds: 400),
    this.longest = const Duration(seconds: 30),
  });

  /// Silence after the last word that ends the turn.
  final Duration silence;

  /// Voice needed to count as speech and not as a click.
  final Duration minSpeech;
  final Duration preRoll;
  final Duration longest;

  static const frameSamples = VoiceActivity.frameSamples;
  static const frameMs = frameSamples * 1000 ~/ speechSampleRate;

  /// Probability of voice that begins a turn and that keeps it going: lower to
  /// keep it, so a syllable that sounds unsure does not look like the end.
  static const startProbability = 0.75;
  static const keepProbability = 0.45;

  /// Quieter than this is not a person close to the phone, whatever the model
  /// says: a television or people in the street are voices too, but far away.
  static const startLoudness = 0.035;

  /// While marlix speaks its voice can leak into the microphone, and a model
  /// that looks for voices takes that for one: the person has to be surer, louder
  /// and last longer.
  /// Share of a turn that has to be voice. A person speaking is voice almost the
  /// whole time; a fan that now and then looks like one is not.
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

  /// Marlix is speaking, so its voice may leak into the microphone.
  bool guarded = false;

  /// Whether a turn is going on: the person has been heard and has not finished.
  bool get speaking => _speaking;

  /// Feeds one frame; returns what happened with it.
  List<TurnEvent> add(VoiceFrame frame) {
    final events = <TurnEvent>[];

    if (!_speaking) {
      final voice = guarded
          ? frame.probability > guardProbability && _loudness(frame.pcm) > guardLoudness
          : frame.probability > startProbability && _loudness(frame.pcm) > startLoudness;
      // A frame that looks unsure does not wipe out the voice heard just before.
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
        // What confirmed the start was voice: the quiet frames before it are not the turn.
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

  /// Ends the turn that was going on (the microphone closed).
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

  /// The silence that closed the turn is not part of what was said.
  TurnEvent _end() {
    final said = _activeFrames - _quietFrames;
    final pcm = _turn.takeBytes();
    return said > 0 && _voicedFrames / said >= minVoiceShare ? TurnEnded(pcm) : const TurnDropped();
  }

  /// Root mean square of the frame, from 0 to 1.
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
