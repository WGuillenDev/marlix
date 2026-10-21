import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { toSpokenText } from '../src/services/speech/spoken-text.js';

describe('toSpokenText', () => {
  it('leaves a plain spoken reply exactly as it is', () => {
    const reply = '¡Qué dicha! Contame, ¿qué fue lo que salió mejor?';
    assert.equal(toSpokenText(reply), reply);
  });

  it('keeps accents, the inverted marks and the tico voseo', () => {
    const reply = '¿Querés que te cuente? ¡Pura vida, mae!';
    assert.equal(toSpokenText(reply), reply);
  });

  describe('emojis', () => {
    it('removes them, with their joiners, skin tones and flags', () => {
      assert.equal(toSpokenText('Qué lindo 😊 me alegra'), 'Qué lindo me alegra');
      assert.equal(toSpokenText('Un abrazo 🫂🐶❤️'), 'Un abrazo');
      assert.equal(toSpokenText('Familia 👨‍👩‍👧 y manos 👍🏽'), 'Familia y manos');
      assert.equal(toSpokenText('Desde 🇨🇷 con cariño'), 'Desde con cariño');
      assert.equal(toSpokenText('Marca 1️⃣ listo'), 'Marca 1 listo');
    });

    it('does not touch digits or text symbols', () => {
      assert.equal(toSpokenText('Son las 5 y 30.'), 'Son las 5 y 30.');
    });
  });

  describe('markdown', () => {
    it('keeps the words of bold, italic, strike and code', () => {
      assert.equal(toSpokenText('Esto es **muy** importante'), 'Esto es muy importante');
      assert.equal(toSpokenText('Esto es __muy__ importante'), 'Esto es muy importante');
      assert.equal(toSpokenText('Es *casi* seguro'), 'Es casi seguro');
      assert.equal(toSpokenText('Es _casi_ seguro'), 'Es casi seguro');
      assert.equal(toSpokenText('Eso ~~no~~ sí'), 'Eso no sí');
      assert.equal(toSpokenText('Decí `hola` y listo'), 'Decí hola y listo');
    });

    it('keeps the text of a link and drops the address', () => {
      assert.equal(toSpokenText('Mirá [esta guía](https://example.com/x?a=1) hoy'), 'Mirá esta guía hoy');
      assert.equal(toSpokenText('Entrá a https://example.com ahora'), 'Entrá a ahora');
      assert.equal(toSpokenText('![un perro](https://example.com/p.png) Coco'), 'un perro Coco');
    });

    it('drops headings marks and quotes marks', () => {
      assert.equal(toSpokenText('## Un respiro\nCon calma.'), 'Un respiro. Con calma.');
      assert.equal(toSpokenText('> Lo dijo ella'), 'Lo dijo ella.');
    });

    it('drops a horizontal rule', () => {
      assert.equal(toSpokenText('Uno.\n---\nDos.'), 'Uno. Dos.');
      assert.equal(toSpokenText('Uno.\n***\nDos.'), 'Uno. Dos.');
    });

    it('turns a list into sentences, one per item', () => {
      assert.equal(
        toSpokenText('Podés:\n- caminar un rato\n- tomar agua\n- llamar a tu hermana'),
        'Podés: caminar un rato. tomar agua. llamar a tu hermana.',
      );
      assert.equal(toSpokenText('1. Respirá\n2) Soltá el aire'), 'Respirá. Soltá el aire.');
      assert.equal(toSpokenText('• Una cosa\n• Otra cosa.'), 'Una cosa. Otra cosa.');
    });

    it('does not take a hyphen in the middle of a line for a list', () => {
      assert.equal(toSpokenText('Es un plan semi-listo'), 'Es un plan semi-listo');
    });

    it('does not take a number in a sentence for a list item', () => {
      assert.equal(toSpokenText('Eran las 3. Nadie vino.'), 'Eran las 3. Nadie vino.');
    });
  });

  describe('symbols', () => {
    it('removes the ones that only mean something on a screen', () => {
      assert.equal(toSpokenText('Mirá ~ esto ^ aquí | ahora'), 'Mirá esto aquí ahora');
      assert.equal(toSpokenText('Eso #importante {pasó}'), 'Eso importante pasó');
    });

    it('says "y" for an ampersand and "por ciento" for a percent', () => {
      assert.equal(toSpokenText('Tu perro & vos'), 'Tu perro y vos');
      assert.equal(toSpokenText('Llevás un 50% del camino'), 'Llevás un 50 por ciento del camino');
      assert.equal(toSpokenText('Un 30 % menos'), 'Un 30 por ciento menos');
    });

    it('turns a dash between words into a pause', () => {
      assert.equal(toSpokenText('Es verdad — y me alegra'), 'Es verdad, y me alegra');
      assert.equal(toSpokenText('Es verdad - y me alegra'), 'Es verdad, y me alegra');
    });

    it('keeps normal punctuation, quotes and parentheses', () => {
      const reply = 'Dijo «hola» (con alegría): ¡sí! ¿Y vos?';
      assert.equal(toSpokenText(reply), reply);
    });

    it('keeps an ellipsis', () => {
      assert.equal(toSpokenText('Bueno… sigamos'), 'Bueno… sigamos');
    });
  });

  describe('spacing', () => {
    it('joins lines and paragraphs into one text with single spaces', () => {
      assert.equal(toSpokenText('Hola.\n\nQué bueno verte.\r\nContame.'), 'Hola. Qué bueno verte. Contame.');
    });

    it('closes the space a removal leaves before punctuation', () => {
      assert.equal(toSpokenText('Qué lindo 😊.'), 'Qué lindo.');
      assert.equal(toSpokenText('Hola 🐶, ¿cómo estás?'), 'Hola, ¿cómo estás?');
    });
  });

  it('gives an empty text when nothing is left to say', () => {
    assert.equal(toSpokenText('😊😊'), '');
    assert.equal(toSpokenText('---'), '');
    assert.equal(toSpokenText('**'), '');
    assert.equal(toSpokenText('   \n  '), '');
    assert.equal(toSpokenText(''), '');
  });

  it('is idempotent: cleaning twice changes nothing', () => {
    const messy = '## Título\n- **Uno** 😊\n- [dos](https://x.co)\nListo & 50%';
    const once = toSpokenText(messy);
    assert.equal(toSpokenText(once), once);
  });
});
