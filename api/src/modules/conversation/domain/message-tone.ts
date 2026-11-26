import { compilePhrasePattern, normalizeForMatching } from '../../../shared/domain/normalize.js';

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

// Default to neutral when the message also contains distress.
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
