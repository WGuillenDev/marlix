List<String> splitSentences(String text) {
  final sentences = <String>[];
  final pending = StringBuffer();
  final runes = text.trim().runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final char = String.fromCharCode(runes[i]);
    pending.write(char);
    final endsSentence = '.!?…'.contains(char);
    final nextIsSpace = i + 1 >= runes.length || String.fromCharCode(runes[i + 1]).trim().isEmpty;
    // Require whitespace or end of text after punctuation to preserve decimals and abbreviations.
    if (endsSentence && nextIsSpace) {
      _flush(pending, sentences);
    }
  }
  _flush(pending, sentences);
  return sentences;
}

/// Split the first sentence at clauses to shorten time to first audio.
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
  if (!sentence.contains(RegExp(r'[\p{L}\p{N}]', unicode: true))) {
    if (sentences.isNotEmpty) sentences[sentences.length - 1] = '${sentences.last} $sentence';
    return;
  }
  sentences.add(sentence);
}

/// Add punctuation-dependent pauses after trimming the model's own silence.
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

List<String> splitClauses(String sentence) => [
  for (final piece in sentence.trim().split(RegExp(r'(?<=[,;:])\s+')))
    if (piece.trim().contains(RegExp(r'[\p{L}\p{N}]', unicode: true))) piece.trim(),
];
