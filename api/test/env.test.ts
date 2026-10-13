import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { EnvValidationError, parseEnv } from '../src/config/env.js';

const validEnv = {
  DEV_ACCESS_TOKEN: 'a'.repeat(32),
  GROQ_API_KEY: 'test-key',
  GROQ_MODEL: 'test-model',
};

describe('parseEnv', () => {
  it('accepts a complete configuration and applies defaults', () => {
    const env = parseEnv(validEnv);

    assert.equal(env.PORT, 3000);
    assert.equal(env.LLM_PROVIDER, 'groq');
    assert.equal(env.GROQ_MODEL, 'test-model');
  });

  it('reads PORT as a number', () => {
    assert.equal(parseEnv({ ...validEnv, PORT: '8080' }).PORT, 8080);
  });

  it('names every missing required variable', () => {
    assert.throws(
      () => parseEnv({}),
      (error: unknown) =>
        error instanceof EnvValidationError &&
        error.invalidVariables.join(',') === 'DEV_ACCESS_TOKEN,GROQ_API_KEY,GROQ_MODEL',
    );
  });

  it('treats an empty value as missing', () => {
    assert.throws(
      () => parseEnv({ ...validEnv, GROQ_API_KEY: '  ' }),
      (error: unknown) =>
        error instanceof EnvValidationError && error.invalidVariables.join(',') === 'GROQ_API_KEY',
    );
  });

  it('rejects an unknown LLM provider', () => {
    assert.throws(() => parseEnv({ ...validEnv, LLM_PROVIDER: 'unknown' }), EnvValidationError);
  });

  it('rejects a development token shorter than 32 characters', () => {
    assert.throws(() => parseEnv({ ...validEnv, DEV_ACCESS_TOKEN: 'short' }), EnvValidationError);
  });

  it('rejects an invalid port', () => {
    assert.throws(() => parseEnv({ ...validEnv, PORT: 'abc' }), EnvValidationError);
  });

  it('never includes a value in the error message', () => {
    try {
      parseEnv({ GROQ_API_KEY: 'secret-value', PORT: 'not-a-port' });
      assert.fail('expected an error');
    } catch (error) {
      assert.ok(error instanceof EnvValidationError);
      assert.ok(!error.message.includes('secret-value'));
      assert.ok(!error.message.includes('not-a-port'));
    }
  });
});
