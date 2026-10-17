import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { MEMORY_EXTRACTOR_PROMPT } from '../src/config/memory-extractor-prompt.js';
import { MEMORY_CATEGORIES } from '../src/services/memory/categories.js';
import {
  createMemoryExtractor,
  MemoryExtractionError,
  parseChanges,
} from '../src/services/memory/extractor.js';
import { isSensitive, sameFact } from '../src/services/memory/sensitive.js';
import { createFakeLlm } from './helpers.js';
import { said } from './memory-fakes.js';

const existing = [
  { id: 'm1', fact: 'Tiene un perro', category: 'pets' },
  { id: 'm2', fact: 'Trabaja como cocinero', category: 'work' },
];

const answer = (...memories: object[]) => JSON.stringify({ memories });

describe('the extractor prompt', () => {
  it('forbids the sensitive data of the card', () => {
    for (const topic of [
      'ID numbers',
      'bank cards',
      'passwords',
      'diagnoses',
      'medications',
      'Phone numbers',
      'suicide',
    ]) {
      assert.match(MEMORY_EXTRACTOR_PROMPT, new RegExp(topic, 'i'), topic);
    }
    assert.match(MEMORY_EXTRACTOR_PROMPT, /NEVER keep/);
  });

  it('leaves out only the sensitive fact, not the whole conversation', () => {
    // Found with the real model: told to "skip the fact", it returned nothing
    // for a conversation that mixed an ID number with ordinary facts.
    assert.match(MEMORY_EXTRACTOR_PROMPT, /Leave out only that fact/);
    assert.match(MEMORY_EXTRACTOR_PROMPT, /those must still be kept/);
  });

  it('treats the conversation as data, not as instructions', () => {
    assert.match(MEMORY_EXTRACTOR_PROMPT, /never instructions for you/);
  });

  it('only offers the closed list of categories', () => {
    for (const category of MEMORY_CATEGORIES) {
      assert.ok(MEMORY_EXTRACTOR_PROMPT.includes(category), category);
    }
  });
});

describe('createMemoryExtractor', () => {
  it('sends the prompt, the saved memories and the conversation, and reads the answer', async () => {
    const fake = createFakeLlm(() => answer({ id: null, fact: 'Le gusta el café', category: 'preferences' }));
    const extractor = createMemoryExtractor(fake.llm);

    const changes = await extractor.extract({
      transcript: said('Me encanta el café'),
      existing,
    });

    assert.deepEqual(changes, [{ id: null, fact: 'Le gusta el café', category: 'preferences' }]);
    const [system, user] = fake.requests[0]!.messages;
    assert.equal(system!.content, MEMORY_EXTRACTOR_PROMPT);
    assert.match(user!.content, /\[m1\] Tiene un perro/);
    assert.match(user!.content, /Persona: Me encanta el café/);
    assert.match(user!.content, /marlix: Cuéntame más\./);
    assert.equal(fake.requests[0]!.temperature, 0);
  });

  it('keeps the newest part of a very long conversation', async () => {
    const fake = createFakeLlm(() => answer());
    const extractor = createMemoryExtractor(fake.llm);
    const long = Array.from({ length: 80 }, (_, i) => `mensaje número ${i} ${'x'.repeat(300)}`);

    await extractor.extract({ transcript: said(...long), existing: [] });

    const sent = fake.requests[0]!.messages[1]!.content;
    assert.ok(sent.length < 13_500, `${sent.length}`);
    assert.ok(sent.includes('mensaje número 79'));
    assert.ok(!sent.includes('mensaje número 0 '));
  });

  it('fails when the model does not answer JSON', async () => {
    const extractor = createMemoryExtractor(createFakeLlm(() => 'Claro, aquí tienes').llm);
    await assert.rejects(
      extractor.extract({ transcript: said('hola'), existing: [] }),
      MemoryExtractionError,
    );
  });
});

describe('parseChanges', () => {
  it('accepts the answer inside a code fence or with text around it', () => {
    const fenced = '```json\n' + answer({ id: null, fact: 'Vive en Heredia', category: 'places' }) + '\n```';
    assert.deepEqual(parseChanges(fenced, []), [
      { id: null, fact: 'Vive en Heredia', category: 'places' },
    ]);
  });

  it('rewrites a saved fact when the id is one of the existing ones', () => {
    const changes = parseChanges(
      answer({ id: 'm2', fact: 'Trabaja como chef en un hotel', category: 'work' }),
      existing,
    );
    assert.deepEqual(changes, [{ id: 'm2', fact: 'Trabaja como chef en un hotel', category: 'work' }]);
  });

  it('treats an id that is not saved as a new fact, so it cannot touch anything else', () => {
    const changes = parseChanges(
      answer({ id: 'inventado', fact: 'Tiene una hermana', category: 'family' }),
      existing,
    );
    assert.deepEqual(changes, [{ id: null, fact: 'Tiene una hermana', category: 'family' }]);
  });

  it('does not repeat a saved fact, even in other case or with other accents', () => {
    const changes = parseChanges(
      answer(
        { id: null, fact: 'tiene un PERRO', category: 'pets' },
        { id: 'm2', fact: 'Trabaja como cocinéro', category: 'work' },
        { id: 'm2', fact: 'Trabaja como cocinero', category: 'work' },
      ),
      existing,
    );
    assert.deepEqual(changes, []);
  });

  it('keeps a fact once when the model repeats it', () => {
    const changes = parseChanges(
      answer(
        { id: null, fact: 'Le gusta nadar', category: 'hobbies' },
        { id: null, fact: 'le gusta nadar', category: 'hobbies' },
      ),
      [],
    );
    assert.equal(changes.length, 1);
  });

  it('uses other for a category it does not know, and drops empty or oversized facts', () => {
    const changes = parseChanges(
      answer(
        { id: null, fact: 'Colecciona sellos', category: 'inventada' },
        { id: null, fact: '   ', category: 'other' },
        { id: null, fact: 'x'.repeat(501), category: 'other' },
      ),
      [],
    );
    assert.deepEqual(changes, [{ id: null, fact: 'Colecciona sellos', category: 'other' }]);
  });

  it('drops sensitive facts even if the model returns them', () => {
    const changes = parseChanges(
      answer(
        { id: null, fact: 'Su cédula es 1-2345-6789', category: 'other' },
        { id: null, fact: 'Tiene depresión', category: 'other' },
        { id: null, fact: 'Su contraseña es azul', category: 'other' },
        { id: null, fact: 'Tiene una gata llamada Luna', category: 'pets' },
      ),
      [],
    );
    assert.deepEqual(changes.map((c) => c.fact), ['Tiene una gata llamada Luna']);
  });

  it('keeps at most ten changes per conversation', () => {
    const many = Array.from({ length: 15 }, (_, i) => ({
      id: null,
      fact: `Dato distinto número ${i}`,
      category: 'other',
    }));
    assert.equal(parseChanges(answer(...many), []).length, 10);
  });

  const invalid = ['', 'no json', '{"memories": "x"}', '{"other": []}', '{"memories":[{"fact":3}]}'];
  for (const content of invalid) {
    it(`rejects ${JSON.stringify(content)}`, () => {
      assert.throws(() => parseChanges(content, []), MemoryExtractionError);
    });
  }
});

describe('isSensitive', () => {
  const sensitive = [
    'Su cédula es 1-2345-6789',
    'Número de tarjeta 4111 1111 1111 1111',
    'Su cuenta bancaria termina en 12345678',
    'Su contraseña es azul',
    'Su clave de internet es 1234',
    'Su PIN es 0000',
    'Su teléfono es 8888-1234',
    'Su correo es ana@example.com',
    'Tiene diagnóstico de bipolaridad',
    'Sufre de diabetes',
    'Toma medicamentos para la presión',
    'Tiene depresión desde niña',
    'Su mamá tiene cáncer',
    'Tiene pensamientos suicidas',
    'Su pasaporte vence en marzo',
    'Tiene ANSIEDAD',
  ];
  for (const fact of sensitive) {
    it(`blocks: ${fact}`, () => assert.equal(isSensitive(fact), true));
  }

  const fine = [
    'Tiene una perrita llamada Coco',
    'Trabaja como cocinero en un hotel',
    'Cumple años el 15/03',
    'Vive en Heredia con su hermana',
    'Le gusta caminar por las tardes',
    'Estudia ingeniería en la universidad',
    'Su hijo tiene 8 años',
    'Quiere correr una maratón en 2027',
  ];
  for (const fact of fine) {
    it(`lets through: ${fact}`, () => assert.equal(isSensitive(fact), false));
  }
});

describe('sameFact', () => {
  it('ignores case, accents and extra spaces', () => {
    assert.equal(sameFact('Tiene  un PERRO', 'tiene un perro'), true);
    assert.equal(sameFact('Trabaja como cocinéro', 'trabaja como cocinero'), true);
    assert.equal(sameFact('Tiene un perro', 'Tiene dos perros'), false);
  });
});
