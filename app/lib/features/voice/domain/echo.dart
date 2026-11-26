List<String> speechWords(String text) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final plain = text.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  return plain.split(RegExp(r'[^a-z0-9]+')).where((word) => word.isNotEmpty).toList();
}

bool isEchoOf(String heard, String said) {
  final words = speechWords(heard);
  if (words.isEmpty) return true;
  final spoken = speechWords(said).toSet();
  return words.every(spoken.contains);
}
