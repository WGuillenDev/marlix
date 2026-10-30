import 'echo.dart';

/// Words a Spanish sentence cannot end on: conjunctions, prepositions,
/// articles, possessives and the fillers people say while they think.
const _openEndings = {
  // conjunctions
  'y', 'e', 'o', 'u', 'pero', 'que', 'porque', 'como', 'cuando', 'donde', 'si', 'aunque',
  'sino', 'ni', 'entonces', 'pues', 'mientras', 'ya',
  // prepositions
  'a', 'al', 'de', 'del', 'en', 'con', 'sin', 'para', 'por', 'sobre', 'entre', 'hacia', 'desde',
  // articles and possessives
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'mi', 'tu', 'su', 'mis', 'tus', 'sus',
  // fillers
  'eh', 'em', 'este', 'osea', 'mm', 'mmm', 'ah', 'bueno', 'tipo',
};

/// Whether what the person said sounds like the middle of a sentence (S6-9),
/// as when they stop to think after "y", "pero" or "eh". Whisper closes a
/// finished sentence with a full stop or a question mark, so a text that ends
/// in one is finished. marlix then waits a little longer for the rest instead
/// of answering half a thought.
bool endsUnfinished(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.endsWith('...') || trimmed.endsWith('…') || trimmed.endsWith(',')) return true;
  if (RegExp(r'[.?!]$').hasMatch(trimmed)) return false;
  final words = speechWords(trimmed);
  return words.isNotEmpty && _openEndings.contains(words.last);
}
