import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

// S1-3: provider SDKs may only be imported inside src/shared/infrastructure/ai/.
const PROVIDER_SDKS = ['openai', 'groq-sdk', '@anthropic-ai/sdk', '@google/genai'];

const srcDir = fileURLToPath(new URL('../src', import.meta.url));
const llmDir = join(srcDir, 'shared', 'infrastructure', 'ai');

function listSourceFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return listSourceFiles(path);
    return entry.name.endsWith('.ts') ? [path] : [];
  });
}

function importsSdk(source: string, sdk: string): boolean {
  const escaped = sdk.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
  const pattern = `(from\\s+|import\\s*\\(\\s*|require\\s*\\(\\s*)['"]${escaped}(/[^'"]*)?['"]`;
  return new RegExp(pattern).test(source);
}

describe('LLM layer boundary', () => {
  it('detects an SDK import', () => {
    assert.ok(importsSdk("import OpenAI from 'openai';", 'openai'));
    assert.ok(importsSdk('import { APIError } from "openai/error";', 'openai'));
    assert.ok(!importsSdk("import { x } from './openai-like.js';", 'openai'));
  });

  it('no file outside shared/infrastructure/ai/ imports a provider SDK', () => {
    const offenders = listSourceFiles(srcDir)
      .filter((file) => !file.startsWith(llmDir + sep))
      .flatMap((file) => {
        const source = readFileSync(file, 'utf8');
        return PROVIDER_SDKS.filter((sdk) => importsSdk(source, sdk)).map(
          (sdk) => `${relative(srcDir, file)} imports ${sdk}`,
        );
      });

    assert.deepEqual(offenders, []);
  });
});

it('keeps module dependencies pointing inward', () => {
  const offenders: string[] = [];
  const imports = /(?:\bfrom\s+|\bimport\s*(?:\(\s*)?)['"]([^'"]+)['"]/g;

  for (const file of listSourceFiles(srcDir)) {
    const source = relative(srcDir, file).split(sep);
    if (source[0] !== 'modules' && source[0] !== 'shared') continue;
    const layer = source[source[0] === 'modules' ? 2 : 1];
    if (layer !== 'domain' && layer !== 'application' && layer !== 'presentation') continue;

    for (const [, reference] of readFileSync(file, 'utf8').matchAll(imports)) {
      if (!reference) continue;
      const target = reference.startsWith('.')
        ? relative(srcDir, resolve(dirname(file), reference)).split(sep)
        : undefined;
      const targetLayer = target?.[target[0] === 'modules' ? 2 : 1];
      const outer = targetLayer === 'infrastructure' ||
        (layer !== 'presentation' && targetLayer === 'presentation');
      const invalid =
        (target === undefined && layer === 'domain') ||
        (target === undefined && layer === 'application' && !reference.startsWith('node:')) ||
        (target !== undefined && targetLayer === undefined) ||
        (layer === 'domain' && targetLayer === 'application') ||
        outer;
      if (invalid) offenders.push(source.join('/') + ' imports ' + reference);
    }
  }

  assert.deepEqual(offenders, []);
});
