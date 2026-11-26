/** What the app records: WAV, 16 kHz, mono, 16-bit PCM. */
export const SAMPLE_RATE = 16_000;
const BYTES_PER_SECOND = SAMPLE_RATE * 2;
const WAV_HEADER_BYTES = 44;
/** A turn is at most 30 s in the app; a little more is allowed. */
export const MAX_SECONDS = 32;
export const MIN_SECONDS = 0.25;
export const MAX_BYTES = WAV_HEADER_BYTES + MAX_SECONDS * BYTES_PER_SECOND;

export function wavSeconds(audio: Uint8Array): number | undefined {
  if (audio.length < WAV_HEADER_BYTES) return undefined;
  const view = new DataView(audio.buffer, audio.byteOffset, audio.byteLength);
  const text = (offset: number) => String.fromCharCode(...audio.subarray(offset, offset + 4));
  const isWav = text(0) === 'RIFF' && text(8) === 'WAVE' && text(12) === 'fmt ';
  const pcm = view.getUint16(20, true) === 1;
  const mono = view.getUint16(22, true) === 1;
  const rate = view.getUint32(24, true) === SAMPLE_RATE;
  const bits = view.getUint16(34, true) === 16;
  if (!isWav || !pcm || !mono || !rate || !bits) return undefined;
  return (audio.length - WAV_HEADER_BYTES) / BYTES_PER_SECOND;
}
