// Validate sensitive content independently of the model's extraction prompt.

const HEALTH_STEMS = [
  'diagnos',
  'trastorno',
  'depresion',
  'ansiedad',
  'bipolar',
  'esquizofren',
  'psiquiatr',
  'cancer',
  'diabet',
  'epilep',
  'vih',
  'enfermedad',
  'padece',
  'sufre de',
  'medicament',
  'medicacion',
  'antidepres',
  'tratamiento medico',
  'suicid',
];

const SECRET_WORDS =
  /\b(contrasena|password|clave|pin|cvv|cedula|pasaporte|iban|tarjeta|cuenta bancaria|cuenta de banco)\b/;

// Catch long digit sequences with common separators used in IDs and accounts.
const LONG_NUMBER = /\d(?:[ -]?\d){7,}/;

const EMAIL = /\S+@\S+\.\S+/;

function normalize(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}

export function isSensitive(fact: string): boolean {
  const text = normalize(fact);
  return (
    LONG_NUMBER.test(text) ||
    EMAIL.test(text) ||
    SECRET_WORDS.test(text) ||
    HEALTH_STEMS.some((stem) => text.includes(stem))
  );
}

export function sameFact(a: string, b: string): boolean {
  return normalize(a).replace(/\s+/g, ' ').trim() === normalize(b).replace(/\s+/g, ' ').trim();
}
