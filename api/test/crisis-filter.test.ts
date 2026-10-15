import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createCrisisFilter, detectCrisisSignal } from '../src/services/crisis/filter.js';
import { normalizeForMatching } from '../src/services/crisis/normalize.js';
import { createFakeLlm, startApp } from './helpers.js';

describe('normalizeForMatching', () => {
  it('ignores case, accents, punctuation, look-alikes and stretched letters', () => {
    assert.equal(normalizeForMatching('¡ME QUIERO MORIR!'), 'me quiero morir');
    assert.equal(normalizeForMatching('Sueño, vergüenza... ¿Qué?'), 'sueno verguenza que');
    assert.equal(normalizeForMatching('m4t4rm3'), 'matarme');
    assert.equal(normalizeForMatching('quierooo moriiiir'), 'quiero morir');
  });
});

describe('detectCrisisSignal', () => {
  const cases: [string, 'risk' | 'ambiguous' | 'normal'][] = [
    // Clear risk, in different spellings.
    ['Me quiero morir', 'risk'],
    ['ya no quiero vivir más', 'risk'],
    ['estoy pensando en el SUICIDIO', 'risk'],
    ['creo que voy a suicidarme', 'risk'],
    ['QUIERO MATARME', 'risk'],
    ['quiero m4t4rme', 'risk'],
    ['quierooo moriiiirme', 'risk'],
    ['pienso en quitarme la vida', 'risk'],
    ['me hago cortes en los brazos', 'risk'],
    ['me violaron', 'risk'],
    // Indirect signals.
    ['ya no aguanto más', 'ambiguous'],
    ['siento que soy una carga para todos', 'ambiguous'],
    ['estarían mejor sin mí', 'ambiguous'],
    ['a veces quisiera dormir y no despertar', 'ambiguous'],
    ['pienso mucho en la muerte', 'ambiguous'],
    ['mi papá me quiere matar', 'ambiguous'],
    // Everyday messages and figurative death.
    ['Hoy me fue mejor en el trabajo', 'normal'],
    ['me muero de risa con ese video', 'normal'],
    ['estoy muerta de cansancio', 'normal'],
    ['me quiero morir de la vergüenza jaja', 'normal'],
    ['me voy a cortar el pelo mañana', 'normal'],
    ['eso no tiene sentido', 'normal'],
  ];

  for (const [message, expected] of cases) {
    it(`"${message}" is ${expected}`, () => {
      assert.equal(detectCrisisSignal(message), expected);
    });
  }
});

describe('createCrisisFilter', () => {
  it('treats ambiguous messages as a crisis until the second layer exists', async () => {
    assert.equal(await createCrisisFilter().isCrisis('ya no aguanto más'), true);
  });

  it('lets the second layer decide ambiguous messages, and only those', async () => {
    const asked: string[] = [];
    const filter = createCrisisFilter(async (message) => {
      asked.push(message);
      return false;
    });

    assert.equal(await filter.isCrisis('ya no aguanto más'), false);
    assert.equal(await filter.isCrisis('me quiero morir'), true);
    assert.equal(await filter.isCrisis('hola'), false);
    assert.deepEqual(asked, ['ya no aguanto más']);
  });

  it('treats a failure of the second layer as a crisis', async () => {
    const filter = createCrisisFilter(() => Promise.reject(new Error('classifier down')));
    assert.equal(await filter.isCrisis('ya no aguanto más'), true);
  });
});

describe('POST /v1/chat with the crisis filter', () => {
  for (const message of ['me quiero morir', 'ya no aguanto más']) {
    it(`answers "${message}" with a crisis reply and never calls the model`, async () => {
      const fake = createFakeLlm();
      const app = await startApp({ llm: fake.llm });
      try {
        const response = await app.postJson('/v1/chat', { message, mode: 'voice' });
        assert.equal(response.status, 200);

        const body = (await response.json()) as Record<string, any>;
        assert.equal(body.type, 'crisis');
        assert.equal(body.userMessage.content, message);
        assert.match(body.reply.content, /9-1-1/);
        assert.equal(body.resources[0].phone, '911');
        assert.equal(body.resources[0].primary, true);
        assert.equal(fake.requests.length, 0);
      } finally {
        await app.close();
      }
    });
  }

  it('sends normal messages to the model as before', async () => {
    const fake = createFakeLlm();
    const app = await startApp({ llm: fake.llm });
    try {
      const response = await app.postJson('/v1/chat', { message: 'me muero de risa' });
      const body = (await response.json()) as Record<string, any>;

      assert.equal(body.type, 'reply');
      assert.equal(body.resources, undefined);
      assert.equal(fake.requests.length, 1);
    } finally {
      await app.close();
    }
  });
});
