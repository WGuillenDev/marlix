/// Splits a reply into the sentences that are spoken one by one. Speaking by
/// sentences is what lets a reply start sooner and lets the voice change engine
/// halfway without repeating what was already said (docs/decisions.md).
List<String> splitSentences(String text) {
  final sentences = <String>[];
  final pending = StringBuffer();
  final runes = text.trim().runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final char = String.fromCharCode(runes[i]);
    pending.write(char);
    final endsSentence = '.!?…'.contains(char);
    final nextIsSpace = i + 1 >= runes.length || String.fromCharCode(runes[i + 1]).trim().isEmpty;
    // "3.5" or "Sr.Pérez" do not end a sentence: it needs a space or the end after it.
    if (endsSentence && nextIsSpace) {
      _flush(pending, sentences);
    }
  }
  _flush(pending, sentences);
  return sentences;
}

/// The pieces a reply is spoken in: its sentences, with the first one cut at
/// its commas (S6-9). The first sound waits for the first piece to be made, so
/// a short one makes marlix start sooner; the rest is made while it speaks.
List<String> splitForSpeech(String text) {
  final sentences = splitSentences(text);
  if (sentences.isEmpty) return sentences;
  final clauses = splitClauses(sentences.first);
  if (clauses.length < 2) return sentences;
  return [...clauses, ...sentences.skip(1)];
}

void _flush(StringBuffer pending, List<String> sentences) {
  final sentence = pending.toString().trim();
  pending.clear();
  if (sentence.isEmpty) return;
  // Only punctuation (such as "...") has nothing to say: join it to the one before.
  if (!sentence.contains(RegExp(r'[\p{L}\p{N}]', unicode: true))) {
    if (sentences.isNotEmpty) sentences[sentences.length - 1] = '${sentences.last} $sentence';
    return;
  }
  sentences.add(sentence);
}

/// Silence left after a piece, by the punctuation it ends with. The model's
/// own silence at the edges is cut (`trimSilence`), so this is all that is
/// heard: a comma short, a period longer, and no dead gap between sentences
/// (S6-14, docs/decisions.md).
const commaPause = Duration(milliseconds: 180);
const semicolonPause = Duration(milliseconds: 280);
const sentencePause = Duration(milliseconds: 350);

Duration pauseAfter(String piece) {
  final end = RegExp(r'([,;:.!?…])[\s"»)\]]*$').firstMatch(piece)?.group(1);
  return switch (end) {
    ',' => commaPause,
    ';' || ':' => semicolonPause,
    '.' || '!' || '?' || '…' => sentencePause,
    _ => Duration.zero,
  };
}

/// Splits one sentence at its commas, semicolons and colons. The punctuation
/// stays in the text, so the voice still raises its tone for a sentence that
/// goes on. A comma inside a number ("3,5") has no space after it and does not
/// split.
List<String> splitClauses(String sentence) => [
  for (final piece in sentence.trim().split(RegExp(r'(?<=[,;:])\s+')))
    if (piece.trim().contains(RegExp(r'[\p{L}\p{N}]', unicode: true))) piece.trim(),
];
