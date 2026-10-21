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

/// A piece of a sentence that ends at a comma, and the silence to leave after it.
typedef Clause = ({String text, Duration pause});

/// Silence after a comma and after a semicolon or a colon. Supertonic reads
/// through commas without stopping, which sounds rushed.
const commaPause = Duration(milliseconds: 200);
const semicolonPause = Duration(milliseconds: 300);

/// Splits one sentence at its commas, semicolons and colons, each with the
/// pause that follows it. The punctuation stays in the text, so the voice still
/// raises its tone for a sentence that goes on. A comma inside a number
/// ("3,5") has no space after it and does not split.
List<Clause> splitClauses(String sentence) {
  final clauses = <Clause>[];
  final pieces = sentence.trim().split(RegExp(r'(?<=[,;:])\s+'));
  for (final piece in pieces) {
    final text = piece.trim();
    if (!text.contains(RegExp(r'[\p{L}\p{N}]', unicode: true))) continue;
    final pause = switch (text[text.length - 1]) {
      ',' => commaPause,
      ';' || ':' => semicolonPause,
      _ => Duration.zero,
    };
    clauses.add((text: text, pause: pause));
  }
  return clauses;
}
