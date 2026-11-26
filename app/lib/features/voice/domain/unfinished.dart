import 'echo.dart';

// These Spanish word classes signal that the sentence may be incomplete.
const _openEndings = {
  'y',
  'e',
  'o',
  'u',
  'pero',
  'que',
  'porque',
  'como',
  'cuando',
  'donde',
  'si',
  'aunque',
  'sino',
  'ni',
  'entonces',
  'pues',
  'mientras',
  'ya',
  'a',
  'al',
  'de',
  'del',
  'en',
  'con',
  'sin',
  'para',
  'por',
  'sobre',
  'entre',
  'hacia',
  'desde',
  'el',
  'la',
  'los',
  'las',
  'un',
  'una',
  'unos',
  'unas',
  'mi',
  'tu',
  'su',
  'mis',
  'tus',
  'sus',
  'eh',
  'em',
  'este',
  'osea',
  'mm',
  'mmm',
  'ah',
  'bueno',
  'tipo',
};

bool endsUnfinished(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.endsWith('...') || trimmed.endsWith('…') || trimmed.endsWith(',')) return true;
  if (RegExp(r'[.?!]$').hasMatch(trimmed)) return false;
  final words = speechWords(trimmed);
  return words.isNotEmpty && _openEndings.contains(words.last);
}
