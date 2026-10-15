// Minimal crisis reply until S2-3 moves the text and the help resources to
// configuration. It always points to 9-1-1 and gives no advice: the goal is
// to reach a person who can help, not to handle the crisis in the chat.

export interface HelpResource {
  id: string;
  name: string;
  /** Digits only, ready to dial. */
  phone: string;
  hours: string;
  primary: boolean;
}

export const CRISIS_REPLY_TEXT =
  'Lo que me contás me importa de verdad, y quiero que tengás ayuda ya. ' +
  'En Costa Rica podés llamar al 9-1-1: es gratis, atienden las 24 horas ' +
  'y te pueden acompañar ahora mismo.';

export const CRISIS_RESOURCES: readonly HelpResource[] = [
  {
    id: '911',
    name: '9-1-1, Despacho de Apoyo Psicológico',
    phone: '911',
    hours: '24/7, gratuito',
    primary: true,
  },
];
