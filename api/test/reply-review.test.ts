import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  reviewReply,
  reviewSentence,
  SAFE_REPLY,
  splitIntoSentences,
} from '../src/services/review/reply-review.js';
import { captureConsole, createFakeLlm, startApp } from './helpers.js';

describe('splitIntoSentences', () => {
  it('splits on sentence punctuation and line breaks, keeping the punctuation', () => {
    const reply = '¡Qué dicha! ¿Cómo te fue?\nContame más… Aquí estoy.';
    assert.deepEqual(splitIntoSentences(reply), [
      '¡Qué dicha!',
      '¿Cómo te fue?',
      'Contame más…',
      'Aquí estoy.',
    ]);
  });
});

describe('reviewSentence', () => {
  const blocked: [string, string][] = [
    ['Podrías tomar sertralina para dormir mejor.', 'clinical_advice'],
    ['Te recomiendo tomar 50 mg antes de acostarte.', 'clinical_advice'],
    ['Un antidepresivo te ayudaría.', 'clinical_advice'],
    ['Por lo que contás, tenés depresión.', 'diagnosis'],
    ['Creo que sufrís de ansiedad generalizada.', 'diagnosis'],
    ['Como tu terapeuta, te digo que descansés.', 'professional_claim'],
    ['No necesitás un psicólogo, me tenés a mí.', 'discourages_help'],
    ['Solo me necesitás a mí.', 'dependence'],
    ['Yo te entiendo mejor que nadie.', 'dependence'],
    ['La dosis letal depende del peso.', 'harmful_information'],
  ];

  for (const [sentence, rule] of blocked) {
    it(`blocks "${sentence}" (${rule})`, () => {
      assert.deepEqual(reviewSentence(sentence), { ok: false, rule });
    });
  }

  const allowed = [
    '¡Qué dicha que te fue bien hoy!',
    'No soy tu terapeuta, pero aquí estoy para escucharte.',
    'Yo no te diagnostico nada, solo te acompaño.',
    'Si te sentís muy mal, hablar con un psicólogo puede ayudarte.',
    'Me gustaría que tengás gente cerca, ¿con quién podrías hablar hoy?',
    'Podés llamar al 9-1-1 cuando lo necesités.',
  ];

  for (const sentence of allowed) {
    it(`lets "${sentence}" through`, () => {
      assert.deepEqual(reviewSentence(sentence), { ok: true });
    });
  }
});

describe('reviewReply', () => {
  it('returns a good reply unchanged', () => {
    const reply = '¡Qué dicha! ¿Qué fue lo que salió bien hoy?';
    assert.deepEqual(reviewReply(reply), { content: reply });
  });

  it('replaces the whole reply when one sentence fails', () => {
    const reply =
      'Entiendo cómo te sentís. Tomate una pastilla de clonazepam. Mañana será mejor.';
    assert.deepEqual(reviewReply(reply), { content: SAFE_REPLY, replacedBy: 'clinical_advice' });
  });

  it('adds no noticeable delay', () => {
    const reply = '¡Qué dicha que me contés eso! '.repeat(40);
    const started = performance.now();
    for (let i = 0; i < 100; i++) reviewReply(reply);
    const perReply = (performance.now() - started) / 100;
    assert.ok(perReply < 5, `took ${perReply.toFixed(2)} ms per reply`);
  });

  it('the safe reply passes its own review', () => {
    assert.deepEqual(reviewReply(SAFE_REPLY), { content: SAFE_REPLY });
  });
});

describe('POST /v1/chat with the reply review', () => {
  it('replaces a problematic model reply and logs only the rule', async () => {
    const app = await startApp({
      llm: createFakeLlm(() => 'Hola. Tenés depresión, deberías tomar fluoxetina.').llm,
    });
    try {
      const { result: response, output } = await captureConsole(() =>
        app.postJson('/v1/chat', { message: 'me cuesta dormir' }),
      );
      const body = (await response.json()) as { type: string; reply: { content: string } };

      assert.equal(body.type, 'reply');
      assert.equal(body.reply.content, SAFE_REPLY);
      assert.match(output, /Reply replaced by the review: clinical_advice/);
      assert.doesNotMatch(output, /fluoxetina|dormir/);
    } finally {
      await app.close();
    }
  });
});
