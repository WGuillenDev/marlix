// Tone of a user message (S5-4): tells the app when the avatar can celebrate.
// Rules over words and emojis, in Spanish as people write it; no model call, so
// it costs no Groq quota and adds no latency.
import { compilePhrasePattern, normalizeForMatching } from '../crisis/normalize.js';

export type MessageTone = 'positive' | 'neutral';

// Longer messages are rarely a simple celebration and the rules cannot read
// them well, so they stay neutral.
const MAX_POSITIVE_LENGTH = 200;

const POSITIVE_PHRASES: readonly string[] = [
  'feliz',
  'felices',
  'content*',
  'genial',
  'excelente',
  'maravillos*',
  'buenisim*',
  'increible',
  'que alegria',
  'me alegra*',
  'me encanta*',
  'me emociona*',
  'emocionad*',
  'me fue bien',
  'me fue muy bien',
  'me fue mejor',
  'me fue genial',
  'me salio bien',
  'salio todo bien',
  'fue un buen dia',
  'fue un dia genial',
  'estoy bien',
  'estoy muy bien',
  'estoy mejor',
  'me siento bien',
  'me siento muy bien',
  'me siento mejor',
  'lo logre',
  'logre',
  'aprobe',
  'me ascendieron',
  'me dieron el trabajo',
];

// Any of these means the message is mixed or negative. Showing joy to someone
// who is struggling is worse than staying neutral, so one hit is enough.
const DOUBT_PHRASES: readonly string[] = [
  'no',
  'ni',
  'nunca',
  'nada',
  'mal',
  'peor',
  'pero',
  'aunque',
  'triste*',
  'horrible',
  'terrible',
  'cansad*',
  'solo',
  'sola',
  'preocupad*',
  'ansios*',
  'ansiedad',
  'miedo',
  'llor*',
  'deprimid*',
  'estres*',
  'enojad*',
  'dolor',
  'sin ganas',
];

const POSITIVE = compilePhrasePattern(POSITIVE_PHRASES);
const DOUBT = compilePhrasePattern(DOUBT_PHRASES);
const POSITIVE_EMOJI = /[😀😃😄😁😊🥰😍🥳🎉💚🙌]/u;

export function detectTone(message: string): MessageTone {
  if ([...message].length > MAX_POSITIVE_LENGTH) return 'neutral';
  const text = normalizeForMatching(message);
  if (DOUBT.test(text)) return 'neutral';
  return POSITIVE.test(text) || POSITIVE_EMOJI.test(message) ? 'positive' : 'neutral';
}
