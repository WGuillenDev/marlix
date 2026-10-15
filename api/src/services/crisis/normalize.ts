// Common ways of writing the same word: "m4t4rme" or "matarmeee".
const LOOKALIKES: Record<string, string> = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '@': 'a',
  $: 's',
};

/**
 * Reduces a text to lowercase letters and single spaces so that case,
 * accents, punctuation, look-alike characters and stretched letters do not
 * change the match. Signals are normalized the same way, so both sides
 * always compare in the same form.
 */
export function normalizeForMatching(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/[013457@$]/g, (character) => LOOKALIKES[character] ?? character)
    .replace(/[^a-z]+/g, ' ')
    .replace(/([a-z])\1+/g, '$1')
    .trim();
}
