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
 * accents, punctuation, look-alike characters, stretched letters and common
 * spellings of "qu" do not change the match. Signals are normalized the same way, so both sides
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
    // "kiero" and "qiero" are common ways of typing "quiero".
    .replace(/[kq](?=[ei])/g, 'qu')
    .trim();
}

/**
 * Builds one pattern that finds any of the phrases, as whole words, in a
 * normalized text. A trailing `*` also matches any ending ("suicid*").
 * With `ignoreNegated`, a phrase right after "no" does not match
 * ("no soy tu terapeuta").
 */
export function compilePhrasePattern(
  phrases: readonly string[],
  { ignoreNegated = false } = {},
): RegExp {
  const alternatives = phrases.map((phrase) => {
    const isPrefix = phrase.endsWith('*');
    const words = normalizeForMatching(isPrefix ? phrase.slice(0, -1) : phrase);
    return isPrefix ? `${words}[a-z]*` : words;
  });
  const notNegated = ignoreNegated ? '(?<!\\bno)' : '';
  return new RegExp(`${notNegated}(?:^| )(?:${alternatives.join('|')})(?: |$)`);
}
