import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { detectTone } from '../src/services/tone/message-tone.js';

describe('detectTone', () => {
  it('is positive for a clearly happy message', () => {
    for (const message of [
      'Hoy me fue muy bien',
      'Estoy feliz!!',
      'Hoy fue un buen día 😊',
      'ME ENCANTA este día',
      'Lo logré, aprobé el examen',
      'Por fin me siento mejor',
      '🎉',
      'Qué alegría ver el sol hoy',
      'Estoy contenta con mi trabajo nuevo',
    ]) {
      assert.equal(detectTone(message), 'positive', message);
    }
  });

  it('is neutral for everyday messages', () => {
    for (const message of ['Hola marlix', 'Qué hora es', 'Cuéntame un chiste', 'Hoy salí a caminar']) {
      assert.equal(detectTone(message), 'neutral', message);
    }
  });

  it('stays neutral when a positive word is negated or mixed with a doubt', () => {
    for (const message of [
      'No me siento bien',
      'No estoy feliz',
      'Hoy no fue un buen día',
      'Estoy bien, pero muy cansado',
      'Me fue bien aunque estoy triste',
      'Estoy feliz pero me siento sola',
      'Nunca me siento mejor',
      'Estoy bien... llorando',
    ]) {
      assert.equal(detectTone(message), 'neutral', message);
    }
  });

  it('reads look-alike characters and stretched letters like the plain word', () => {
    assert.equal(detectTone('hoy me fue m4l'), 'neutral');
    assert.equal(detectTone('estoy feeeeliz'), 'positive');
    assert.equal(detectTone('m3 enc4nta'), 'positive');
  });

  it('keeps long messages neutral even with a positive phrase', () => {
    assert.equal(detectTone(`Hoy me fue muy bien. ${'Te cuento cómo pasó todo. '.repeat(20)}`), 'neutral');
  });

  it('does not treat a greeting or a thank-you as positive', () => {
    assert.equal(detectTone('Buen día marlix'), 'neutral');
    assert.equal(detectTone('Gracias'), 'neutral');
  });
});
