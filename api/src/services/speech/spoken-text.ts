// Text for the phone's voice (S6-3). The model is asked for plain spoken
// sentences, but a reply can still carry what is written for the eye and not
// for the ear: emojis, markdown, list markers and symbols the voice reads
// aloud ("asterisco asterisco") or skips with a strange pause.

const EMOJI = /\p{Extended_Pictographic}|\p{Emoji_Presentation}|[\u{1F1E6}-\u{1F1FF}\u{1F3FB}-\u{1F3FF}‍️⃣]/gu;

// A line that starts a list item: "- ", "* ", "• " or "1. " / "1) ".
const LIST_MARKER = /^\s*(?:[-*+•·]|\d{1,2}[.)])\s+/;
const HEADING_OR_QUOTE = /^\s*(?:#{1,6}\s+|>+\s?)/;
const RULE_LINE = /^\s*(?:[-*_]\s*){3,}$/;
const ENDS_A_SENTENCE = /[.!?…:;]["')»”]*$/;

/**
 * Leaves a reply as it should be said. Applied in voice mode only, before the
 * reply review, so the review, the history and the distilled memory all see
 * the same words that are spoken.
 */
export function toSpokenText(reply: string): string {
  const lines: string[] = [];
  for (const raw of reply.replace(/\r\n?/g, '\n').split('\n')) {
    if (RULE_LINE.test(raw)) continue;

    const structural = LIST_MARKER.test(raw) || HEADING_OR_QUOTE.test(raw);
    let line = raw.replace(LIST_MARKER, '').replace(HEADING_OR_QUOTE, '');
    line = cleanInline(line);
    if (!hasWords(line)) continue;

    // Each list item or title is a sentence of its own: without a full stop the
    // voice would run it into the next one.
    if (structural && !ENDS_A_SENTENCE.test(line)) line += '.';
    lines.push(line);
  }
  return lines.join(' ').replace(/\s+/g, ' ').replace(/\s+([,.;:!?…])/g, '$1').trim();
}

function cleanInline(text: string): string {
  return (
    text
      // ![alt](url) and [text](url) keep only their words; a bare address is not read.
      .replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1')
      .replace(/https?:\/\/\S+/g, '')
      .replace(EMOJI, '')
      .replace(/`{1,3}/g, '')
      // **bold**, __bold__, *italic*, ~~strike~~: the marks go, the words stay.
      .replace(/(\*\*|__|~~)(.+?)\1/g, '$2')
      .replace(/\*(\S(?:.*?\S)?)\*/g, '$1')
      .replace(/(?<![\p{L}\p{N}])_(\S(?:.*?\S)?)_(?![\p{L}\p{N}])/gu, '$1')
      // What is left of the marks, and symbols that only mean something on a screen.
      .replace(/[*~^|\\<>{}[\]#=_]/g, ' ')
      .replace(/\s*&\s*/g, ' y ')
      .replace(/(\d)\s*%/g, '$1 por ciento')
      // A dash between words is a pause.
      .replace(/\s+[—–-]\s+|\s*[—–]\s*/g, ', ')
      .replace(/\s+/g, ' ')
      .trim()
  );
}

function hasWords(text: string): boolean {
  return /[\p{L}\p{N}]/u.test(text);
}
