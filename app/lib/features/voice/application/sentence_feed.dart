import 'dart:async';
import 'dart:collection';

import '../domain/sentences.dart';

/// Buffers arriving sentences without blocking playback of the current one.
class SentenceFeed {
  SentenceFeed.complete(Iterable<String> pieces) : _closed = true {
    for (final piece in pieces) {
      _queue.add(piece);
      _totalChars += piece.length;
    }
  }

  SentenceFeed.live(Stream<String> source) : _closed = false {
    _subscription = source.listen(_add, onDone: _close, onError: (Object _) => _close());
  }

  final _queue = Queue<String>();
  StreamSubscription<String>? _subscription;
  Completer<void>? _waiting;
  bool _closed;
  var _totalChars = 0;

  // Split the first sentence at pauses to reduce time to first audio.
  var _firstPending = true;

  int get totalChars => _totalChars;

  String? get upcoming => _queue.firstOrNull;

  /// The next piece to say, waiting for it if needed; null once there are no
  /// more, or after [cancel].
  Future<String?> next() async {
    while (_queue.isEmpty) {
      if (_closed) return null;
      await (_waiting = Completer<void>()).future;
    }
    return _queue.removeFirst();
  }

  /// Nothing else will be said: a waiting [next] ends and the source is left.
  void cancel() {
    _queue.clear();
    _close();
  }

  void _add(String sentence) {
    if (_closed) return;
    final pieces = _firstPending ? splitForSpeech(sentence) : [sentence];
    if (pieces.isEmpty) return;
    _firstPending = false;
    for (final piece in pieces) {
      _queue.add(piece);
      _totalChars += piece.length;
    }
    _wake();
  }

  void _close() {
    _closed = true;
    // Cancellation can stall after the source stream closes.
    unawaited(_subscription?.cancel());
    _wake();
  }

  void _wake() {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }
}
