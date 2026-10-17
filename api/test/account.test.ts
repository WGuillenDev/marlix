import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import { RECENT_SIGN_IN_SECONDS } from '../src/routes/account.js';
import { DatabaseError } from '../src/services/database-error.js';
import { createSupabaseAccountStore } from '../src/services/account/supabase-account-store.js';
import { fakeSupabaseClient } from './fake-supabase.js';
import { captureConsole, createFakeLlm, signSession, startApp } from './helpers.js';
import { createFakeAccounts } from './memory-fakes.js';

const USER = '00000000-0000-4000-8000-00000000000a';

const secondsAgo = (seconds: number) => Math.floor(Date.now() / 1000) - seconds;
const bearer = async (claims: Record<string, unknown> = {}) => ({
  authorization: `Bearer ${await signSession({ claims })}`,
});

describe('DELETE /v1/account', () => {
  const accounts = createFakeAccounts();
  let app: Awaited<ReturnType<typeof startApp>>;

  const deleteAccount = (headers: Record<string, string> = app.authHeader) =>
    app.request('/v1/account', { method: 'DELETE', headers });

  before(async () => {
    app = await startApp({ llm: createFakeLlm().llm, accounts: accounts.store });
  });
  after(() => app.close());
  beforeEach(() => {
    accounts.deleted.length = 0;
  });

  it('deletes the account of the person after a recent sign-in', async () => {
    const response = await deleteAccount();

    assert.equal(response.status, 204);
    assert.equal(await response.text(), '');
    assert.deepEqual(accounts.deleted, [USER]);
  });

  it('accepts a sign-in a few seconds inside the window', async () => {
    const response = await deleteAccount(
      await bearer({ amr: [{ method: 'password', timestamp: secondsAgo(RECENT_SIGN_IN_SECONDS - 5) }] }),
    );
    assert.equal(response.status, 204);
  });

  it('asks to sign in again, and deletes nothing, when the sign-in is older than 5 minutes', async () => {
    const response = await deleteAccount(
      await bearer({ amr: [{ method: 'password', timestamp: secondsAgo(RECENT_SIGN_IN_SECONDS + 5) }] }),
    );

    assert.equal(response.status, 401);
    assert.equal(((await response.json()) as any).error.code, 'REAUTHENTICATION_REQUIRED');
    assert.deepEqual(accounts.deleted, []);
  });

  it('does not take a refreshed token for a recent sign-in: only the amr time counts', async () => {
    const response = await deleteAccount(
      await bearer({
        iat: secondsAgo(1),
        amr: [{ method: 'password', timestamp: secondsAgo(3 * 3600) }],
      }),
    );

    assert.equal(response.status, 401);
    assert.equal(((await response.json()) as any).error.code, 'REAUTHENTICATION_REQUIRED');
    assert.deepEqual(accounts.deleted, []);
  });

  it('uses the newest sign-in when the token lists several', async () => {
    const response = await deleteAccount(
      await bearer({
        amr: [
          { method: 'password', timestamp: secondsAgo(3 * 3600) },
          { method: 'otp', timestamp: secondsAgo(10) },
        ],
      }),
    );
    assert.equal(response.status, 204);
  });

  it('treats a token without a usable amr claim as an old session', async () => {
    for (const amr of [undefined, [], 'password', [{ method: 'password' }], [{ timestamp: 'now' }], [null]]) {
      const response = await deleteAccount(await bearer({ amr: amr as never }));
      assert.equal(response.status, 401, JSON.stringify(amr));
      assert.equal(((await response.json()) as any).error.code, 'REAUTHENTICATION_REQUIRED');
    }
    assert.deepEqual(accounts.deleted, []);
  });

  it('answers 401 UNAUTHORIZED without a valid session, and deletes nothing', async () => {
    for (const headers of [{}, { authorization: 'Bearer nope' }]) {
      const response = await deleteAccount(headers);
      assert.equal(response.status, 401);
      assert.equal(((await response.json()) as any).error.code, 'UNAUTHORIZED');
    }
    assert.deepEqual(accounts.deleted, []);
  });

  it('only ever deletes the account of the token', async () => {
    const other = '00000000-0000-4000-8000-00000000000b';
    await deleteAccount(await bearer({ sub: other }));
    assert.deepEqual(accounts.deleted, [other]);
  });

  it('answers 500 without leaking anything when the deletion fails', async () => {
    const failing = await startApp({
      llm: createFakeLlm().llm,
      accounts: {
        deleteAccount: async () => {
          throw new DatabaseError();
        },
      },
    });
    try {
      const { result: response } = await captureConsole(() =>
        failing.request('/v1/account', { method: 'DELETE', headers: failing.authHeader }),
      );
      assert.equal(response.status, 500);
      assert.equal(((await response.json()) as any).error.code, 'INTERNAL_ERROR');
    } finally {
      await failing.close();
    }
  });
});

describe('createSupabaseAccountStore', () => {
  it('hard-deletes the user with the Auth admin API', async () => {
    const { client, calls } = fakeSupabaseClient(() => ({ body: {} }));

    await createSupabaseAccountStore(client).deleteAccount(USER);

    assert.equal(calls.length, 1);
    assert.equal(calls[0]!.method, 'DELETE');
    assert.equal(calls[0]!.table, USER);
    assert.deepEqual(calls[0]!.body, { should_soft_delete: false });
  });

  it('is done when the user was already deleted', async () => {
    const { client } = fakeSupabaseClient(() => ({
      status: 404,
      body: { code: 404, error_code: 'user_not_found', msg: 'User not found' },
    }));
    await createSupabaseAccountStore(client).deleteAccount(USER);
  });

  it('fails, logging only the code, for any other error', async () => {
    const { client } = fakeSupabaseClient(() => ({
      status: 403,
      body: { code: 403, error_code: 'not_admin', msg: 'ana@example.com could not be deleted' },
    }));

    const { result, output } = await captureConsole(() =>
      createSupabaseAccountStore(client)
        .deleteAccount(USER)
        .catch((error: unknown) => error),
    );

    assert.ok(result instanceof DatabaseError);
    assert.match(output, /not_admin/);
    assert.doesNotMatch(output + (result as Error).message, /ana@example\.com/);
  });
});
