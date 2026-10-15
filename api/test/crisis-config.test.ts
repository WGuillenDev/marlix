import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  CrisisConfigError,
  loadCrisisConfig,
  parseCrisisConfig,
  type CrisisConfig,
} from '../src/config/crisis-config.js';
import { createFakeLlm, startApp } from './helpers.js';

const shipped = loadCrisisConfig();

function withChanges(changes: Partial<CrisisConfig>): unknown {
  return { ...structuredClone(shipped), ...changes };
}

describe('crisis configuration', () => {
  it('ships a valid configuration with 9-1-1 first and every card resource', () => {
    assert.equal(shipped.resources[0]?.phone, '911');
    assert.equal(shipped.resources[0]?.primary, true);
    assert.deepEqual(
      shipped.resources.map((resource) => resource.phone),
      ['911', '8002737869', '22257511', '22342730'],
    );
    assert.match(shipped.reply, /9-1-1/);
  });

  const invalid: [string, unknown][] = [
    ['a reply that does not mention 9-1-1', withChanges({ reply: 'Estoy aquí para vos.' })],
    [
      'no primary resource',
      withChanges({ resources: shipped.resources.map((r) => ({ ...r, primary: false })) }),
    ],
    [
      'two primary resources',
      withChanges({ resources: shipped.resources.map((r) => ({ ...r, primary: true })) }),
    ],
    [
      'a primary resource other than 9-1-1',
      withChanges({ resources: [...shipped.resources].reverse() }),
    ],
    [
      'a phone with dashes',
      withChanges({
        resources: shipped.resources.map((r, i) => (i === 1 ? { ...r, phone: '800-2737869' } : r)),
      }),
    ],
    [
      'repeated ids',
      withChanges({ resources: [shipped.resources[0]!, shipped.resources[0]!] }),
    ],
    ['an invalid date', withChanges({ updatedAt: 'ayer' })],
  ];

  for (const [name, raw] of invalid) {
    it(`refuses ${name}`, () => {
      assert.throws(() => parseCrisisConfig(raw), CrisisConfigError);
    });
  }
});

describe('GET /v1/help-resources', () => {
  it('is public and serves the configured resources', async () => {
    const app = await startApp({ llm: createFakeLlm().llm });
    try {
      const response = await app.request('/v1/help-resources');
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), {
        updatedAt: shipped.updatedAt,
        resources: shipped.resources,
      });
    } finally {
      await app.close();
    }
  });
});

describe('changing a number in the configuration', () => {
  it('reaches the help screen and the crisis reply without code changes', async () => {
    const crisisConfig = parseCrisisConfig(
      withChanges({
        resources: shipped.resources.map((r) =>
          r.id === 'aqui-estoy' ? { ...r, phone: '8000000000' } : r,
        ),
      }),
    );
    const fake = createFakeLlm();
    const app = await startApp({ llm: fake.llm, crisisConfig });
    try {
      type CrisisBody = Pick<CrisisConfig, 'resources'> & {
        type: string;
        reply: { content: string };
      };
      const help = (await (await app.request('/v1/help-resources')).json()) as CrisisConfig;
      const crisisResponse = await app.postJson('/v1/chat', { message: 'me quiero morir' });
      const crisis = (await crisisResponse.json()) as CrisisBody;

      assert.equal(help.resources[1]?.phone, '8000000000');
      assert.equal(crisis.type, 'crisis');
      assert.equal(crisis.reply.content, shipped.reply);
      assert.deepEqual(crisis.resources, help.resources);
      assert.equal(fake.requests.length, 0);
    } finally {
      await app.close();
    }
  });
});
