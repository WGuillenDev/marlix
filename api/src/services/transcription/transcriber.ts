// Speech to text for the voice mode (S6-9). Decision: docs/decisions.md.

/** Turns what the person said into text. Throws LlmError when the provider fails. */
export interface Transcriber {
  transcribe(audio: Uint8Array): Promise<string>;
}

/**
 * Whisper writes these on silence or noise: they come from the subtitles it
 * was trained on, not from the person. Compared without case or punctuation.
 */
const SILENCE_PHRASES = [
  'gracias por ver el video',
  'gracias por ver',
  'subtitulos realizados por la comunidad de amaraorg',
  'subtitulado por la comunidad de amaraorg',
  'suscribete',
  'gracias',
];

function plain(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9 ]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/** The text without Whisper's phrases for silence; empty if nothing real was said. */
export function cleanTranscript(text: string): string {
  const trimmed = text.trim();
  return SILENCE_PHRASES.includes(plain(trimmed)) ? '' : trimmed;
}

/** What Whisper reports about each stretch of audio it wrote down. */
export interface TranscribedSegment {
  text: string;
  no_speech_prob: number;
  avg_logprob: number;
  compression_ratio: number;
}

/**
 * Whisper writes sentences on noise, like a fan or the street, and tells how
 * little it believes them: the odds that nobody spoke, how unsure its words were
 * and how repetitive the text is. A stretch it doubts on those counts is noise.
 */
export function isNoise(segment: TranscribedSegment): boolean {
  return (
    segment.no_speech_prob > 0.85 ||
    (segment.no_speech_prob > 0.6 && segment.avg_logprob < -1) ||
    segment.compression_ratio > 2.4
  );
}

/** The text of the stretches that are speech, cleaned; empty if it was all noise. */
export function speechOf(segments: readonly TranscribedSegment[]): string {
  return cleanTranscript(
    segments
      .filter((segment) => !isNoise(segment))
      .map((segment) => segment.text.trim())
      .join(' '),
  );
}
