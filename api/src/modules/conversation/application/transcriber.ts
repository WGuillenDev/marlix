
export interface Transcriber {
  transcribe(audio: Uint8Array): Promise<string>;
}

/** Whisper can reproduce training subtitles during silence. Match them without punctuation. */
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

export function cleanTranscript(text: string): string {
  const trimmed = text.trim();
  return SILENCE_PHRASES.includes(plain(trimmed)) ? '' : trimmed;
}

export interface TranscribedSegment {
  text: string;
  no_speech_prob: number;
  avg_logprob: number;
  compression_ratio: number;
}

/** Use segment confidence to suppress transcription of background noise. */
export function isNoise(segment: TranscribedSegment): boolean {
  return (
    segment.no_speech_prob > 0.85 ||
    (segment.no_speech_prob > 0.6 && segment.avg_logprob < -1) ||
    segment.compression_ratio > 2.4
  );
}

export function speechOf(segments: readonly TranscribedSegment[]): string {
  return cleanTranscript(
    segments
      .filter((segment) => !isNoise(segment))
      .map((segment) => segment.text.trim())
      .join(' '),
  );
}
