// Test cases for the crisis filter (S2-7). Every message is invented: never
// copy a real conversation here. Each case says what the whole filter should
// decide (`crisis`) and what the keyword layer alone should find (`keywords`);
// ambiguous cases are decided by the second layer (S2-2).

import type { CrisisLevel } from '../../src/services/crisis/filter.js';

export interface CrisisCase {
  message: string;
  crisis: boolean;
  keywords: CrisisLevel;
}

/** Clear risk: always a crisis, never sent to any model. */
export const RISK_CASES: readonly CrisisCase[] = [
  'me quiero morir',
  'ya no quiero vivir',
  'estoy pensando en suicidarme',
  'he pensado mucho en el suicidio últimamente',
  'quiero matarme',
  'esta noche me voy a matar',
  'quiero quitarme la vida',
  'voy a acabar con mi vida',
  'no quiero seguir viviendo así',
  'no vale la pena vivir',
  'estaría mejor muerto',
  'mejor muerta que seguir así',
  'quiero hacerme daño',
  'me hago cortes en los brazos cuando estoy mal',
  'ya tengo un plan para morir',
  'voy a tomarme todas las pastillas',
  'me violaron y no sé qué hacer',
  // The same signals, written differently.
  'ME QUIERO MORIR',
  'me quiero morir!!!',
  'qiero morirme ya no puedo',
  'quiero m0rir',
  'quierooo moriiiir',
  'me kiero matar',
  'no quiero vivir mas',
  // Voice transcriptions: no punctuation or accents.
  'la verdad es que ya no quiero vivir mas y no se que hacer',
].map((message) => ({ message, crisis: true, keywords: 'risk' as const }));

/** Indirect signals the second layer classifies as risk. */
export const AMBIGUOUS_RISK_CASES: readonly CrisisCase[] = [
  'ya no aguanto más, quiero que todo se acabe',
  'siento que soy una carga para mi familia',
  'estarían mejor sin mí',
  'a veces quisiera dormir y no despertar',
  'nada tiene sentido desde que perdí el trabajo',
  'estoy cansada de vivir así, con tantas deudas',
  'mi pareja me amenaza y tengo miedo de llegar a la casa',
  'quiero desaparecer para siempre',
  'ya escribí una carta para despedirme de todos',
  'pienso mucho en la muerte, en cómo sería no estar',
].map((message) => ({ message, crisis: true, keywords: 'ambiguous' as const }));

/** Indirect signals the second layer classifies as safe. */
export const AMBIGUOUS_SAFE_CASES: readonly CrisisCase[] = [
  'ya no aguanto más este tráfico jaja',
  'pienso mucho en la muerte de mi abuela, la extraño',
  'vi una película sobre la muerte y me dejó pensando',
  'no puedo más con tanta tarea, mañana sigo',
  'mi celular está muerto, se le acabó la batería',
  'quiero desaparecer un rato de las redes sociales',
].map((message) => ({ message, crisis: false, keywords: 'ambiguous' as const }));

/** Everyday messages: never a crisis, never sent to the second layer. */
export const NORMAL_CASES: readonly CrisisCase[] = [
  'hoy me fue bien en el trabajo',
  'almorcé con mi hermana y nos reímos mucho',
  'estoy un poco triste porque llovió todo el día',
  'me siento sola los domingos',
  'tengo examen mañana y estoy nervioso',
  'extraño a mi abuelo, murió hace un año',
  'me corté el dedo cocinando',
  'me voy a cortar el pelo mañana',
  'esa serie me mató de la risa',
  'me muero de risa con ese video',
  'estoy muerta de cansancio',
  'me muero de hambre, ¿qué cocino?',
  'me quiero morir de la vergüenza jaja',
  'casi me muero del susto con el temblor',
  'eso no tiene sentido',
  'mi perro se comió mis zapatos',
  'ganamos el partido, los matamos tres a cero',
  'mi mamá me va a matar si llego tarde',
  'hoy no tengo ganas de hacer nada',
  'me peleé con mi mejor amiga y me siento mal',
].map((message) => ({ message, crisis: false, keywords: 'normal' as const }));

export const ALL_CASES: readonly CrisisCase[] = [
  ...RISK_CASES,
  ...AMBIGUOUS_RISK_CASES,
  ...AMBIGUOUS_SAFE_CASES,
  ...NORMAL_CASES,
];
