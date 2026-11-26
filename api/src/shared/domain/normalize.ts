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

/** Matches whole words, supports trailing wildcards and can skip phrases after "no". */
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
