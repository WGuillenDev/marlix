/// Words of [text] as the recognizer would write them: lowercase, without
/// accents or punctuation.
List<String> speechWords(String text) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final plain = text.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  return plain.split(RegExp(r'[^a-z0-9]+')).where((word) => word.isNotEmpty).toList();
}

/// Whether what the microphone heard is only marlix's own voice coming back
/// through the speaker (S6-9): every word it heard is a word of what marlix
/// said. The person saying anything else, even a single new word, is not an
/// echo, so they can still interrupt.
bool isEchoOf(String heard, String said) {
  final words = speechWords(heard);
  if (words.isEmpty) return true;
  final spoken = speechWords(said).toSet();
  return words.every(spoken.contains);
}
