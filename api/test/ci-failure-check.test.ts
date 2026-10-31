import assert from 'node:assert/strict';
import { it } from 'node:test';

it('fails on purpose to check that the CI catches it (S7-2)', () => {
  assert.equal(1, 2);
});
