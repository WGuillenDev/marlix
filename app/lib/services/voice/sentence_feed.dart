import 'dart:async';
import 'dart:collection';

import 'sentences.dart';

/// The sentences a voice has to say, which can still be arriving while it
/// speaks (S6-10). The voice takes them one by one and waits for the next one
/// when it gets ahead of the backend.
class SentenceFeed {
  /// A reply that is already whole.
  SentenceFeed.complete(Iterable<String> pieces) : _closed = true {
    for (final piece in pieces) {
      _queue.add(piece);
      _totalChars += piece.length;
    }
  }

  /// A reply that is still being written: [source] carries its sentences and
  /// closes when it is done.
  SentenceFeed.live(Stream<String> source) : _closed = false {
    _subscription = source.listen(_add, onDone: _close, onError: (Object _) => _close());
  }

  final _queue = Queue<String>();
  StreamSubscription<String>? _subscription;
  Completer<void>? _waiting;
  bool _closed;
  var _totalChars = 0;

  /// The first sentence is cut at its commas, so the first sound waits for a
  /// short piece (S6-9).
  var _firstPending = true;

  /// How much text has arrived so far, for the progress of the reading.
  int get totalChars => _totalChars;

  /// The piece after the one being said, if it is already here, so the engine
  /// can make it ahead of time.
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
    // Not awaited: cancelling the subscription of a stream that already ended
    // may never answer.
    unawaited(_subscription?.cancel());
    _wake();
  }

  void _wake() {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }
}
