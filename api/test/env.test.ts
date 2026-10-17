import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { EnvValidationError, parseEnv } from '../src/config/env.js';

const validEnv = {
  GROQ_API_KEY: 'test-key',
  GROQ_MODEL: 'test-model',
  SUPABASE_URL: 'https://abcdefghijklmnop.supabase.co',
  SUPABASE_SECRET_KEY: 'sb_secret_test-key',
};

describe('parseEnv', () => {
  it('accepts a complete configuration and applies defaults', () => {
    const env = parseEnv(validEnv);

    assert.equal(env.PORT, 3000);
    assert.equal(env.LLM_PROVIDER, 'groq');
    assert.equal(env.GROQ_MODEL, 'test-model');
  });

  it('sends 16 messages of context by default, and the size can be changed', () => {
    assert.equal(parseEnv(validEnv).CHAT_CONTEXT_MESSAGES, 16);
    assert.equal(parseEnv({ ...validEnv, CHAT_CONTEXT_MESSAGES: '20' }).CHAT_CONTEXT_MESSAGES, 20);
    for (const size of ['0', '1', '41', 'muchos', '15.5']) {
      assert.throws(
        () => parseEnv({ ...validEnv, CHAT_CONTEXT_MESSAGES: size }),
        EnvValidationError,
        size,
      );
    }
  });

  it('reads PORT as a number', () => {
    assert.equal(parseEnv({ ...validEnv, PORT: '8080' }).PORT, 8080);
  });

  it('names every missing required variable', () => {
    assert.throws(
      () => parseEnv({}),
      (error: unknown) =>
        error instanceof EnvValidationError &&
        error.invalidVariables.join(',') ===
          'GROQ_API_KEY,GROQ_MODEL,SUPABASE_SECRET_KEY,SUPABASE_URL',
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

  it('rejects a Supabase URL that is not a project URL', () => {
    for (const url of ['http://abcdefghijklmnop.supabase.co', 'https://example.com', 'not-a-url']) {
      assert.throws(() => parseEnv({ ...validEnv, SUPABASE_URL: url }), EnvValidationError, url);
    }
  });

  it('accepts only a Supabase secret key, not a publishable or legacy one', () => {
    for (const key of ['sb_publishable_abc', 'eyJhbGciOiJIUzI1NiJ9.e30.x']) {
      assert.throws(() => parseEnv({ ...validEnv, SUPABASE_SECRET_KEY: key }), EnvValidationError);
    }
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
