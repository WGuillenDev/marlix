import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

// S1-3: provider SDKs may only be imported inside src/services/llm/.
const PROVIDER_SDKS = ['openai', 'groq-sdk', '@anthropic-ai/sdk', '@google/genai'];

const srcDir = fileURLToPath(new URL('../src', import.meta.url));
const llmDir = join(srcDir, 'services', 'llm');

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

  it('no file outside services/llm/ imports a provider SDK', () => {
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
