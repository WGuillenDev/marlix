import 'dart:math' as math;

/// Cuts the silence at the start and at the end of [audio], leaving [keep] on
/// each side. The voice model ends every piece with its own silence, which adds
/// to the pause we put between pieces (S6-14).
List<double> trimSilence(
  List<double> audio,
  int sampleRate, {
  double threshold = 0.01,
  Duration keep = const Duration(milliseconds: 30),
}) {
  final window = math.max(1, (sampleRate * 0.01).round());
  bool loud(int start) {
    final end = math.min(start + window, audio.length);
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      sum += audio[i] * audio[i];
    }
    return math.sqrt(sum / (end - start)) >= threshold;
  }

  var first = 0;
  while (first < audio.length && !loud(first)) {
    first += window;
  }
  if (first >= audio.length) return const [];

  var last = ((audio.length - 1) ~/ window) * window;
  while (last > first && !loud(last)) {
    last -= window;
  }

  final margin = (sampleRate * keep.inMicroseconds / Duration.microsecondsPerSecond).round();
  final from = math.max(0, first - margin);
  final to = math.min(audio.length, last + window + margin);
  return audio.sublist(from, to);
}
