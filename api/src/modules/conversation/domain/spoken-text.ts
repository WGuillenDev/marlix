
const EMOJI = /\p{Extended_Pictographic}|\p{Emoji_Presentation}|[\u{1F1E6}-\u{1F1FF}\u{1F3FB}-\u{1F3FF}‍️⃣]/gu;

const LIST_MARKER = /^\s*(?:[-*+•·]|\d{1,2}[.)])\s+/;
const HEADING_OR_QUOTE = /^\s*(?:#{1,6}\s+|>+\s?)/;
const RULE_LINE = /^\s*(?:[-*_]\s*){3,}$/;
const ENDS_A_SENTENCE = /[.!?…:;]["')»”]*$/;

/** Clean voice replies before review, storage and playback so all three see the same text. */
export function toSpokenText(reply: string): string {
  const lines: string[] = [];
  for (const raw of reply.replace(/\r\n?/g, '\n').split('\n')) {
    if (RULE_LINE.test(raw)) continue;

    const structural = LIST_MARKER.test(raw) || HEADING_OR_QUOTE.test(raw);
    let line = raw.replace(LIST_MARKER, '').replace(HEADING_OR_QUOTE, '');
    line = cleanInline(line);
    if (!hasWords(line)) continue;

    // Add pauses between list items so they do not run together in speech.
    if (structural && !ENDS_A_SENTENCE.test(line)) line += '.';
    lines.push(line);
  }
  return lines.join(' ').replace(/\s+/g, ' ').replace(/\s+([,.;:!?…])/g, '$1').trim();
}

function cleanInline(text: string): string {
  return (
    text
      .replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1')
      .replace(/https?:\/\/\S+/g, '')
      .replace(EMOJI, '')
      .replace(/`{1,3}/g, '')
      .replace(/(\*\*|__|~~)(.+?)\1/g, '$2')
      .replace(/\*(\S(?:.*?\S)?)\*/g, '$1')
      .replace(/(?<![\p{L}\p{N}])_(\S(?:.*?\S)?)_(?![\p{L}\p{N}])/gu, '$1')
      .replace(/[*~^|\\<>{}[\]#=_]/g, ' ')
      .replace(/\s*&\s*/g, ' y ')
      .replace(/(\d)\s*%/g, '$1 por ciento')
      .replace(/\s+[—–-]\s+|\s*[—–]\s*/g, ', ')
      .replace(/\s+/g, ' ')
      .trim()
  );
}

function hasWords(text: string): boolean {
  return /[\p{L}\p{N}]/u.test(text);
}
