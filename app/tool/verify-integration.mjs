import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const configs = new Map([
  ['local', 'config/integration.local.json'],
  ['staging', 'config/staging.json'],
]);
const localApiHosts = new Set(['10.0.2.2', '127.0.0.1', 'localhost']);
const usage = 'Usage: node tool/verify-integration.mjs <local|staging> [--check]';

function readConfig(configPath) {
  try {
    return JSON.parse(readFileSync(new URL(`../${configPath}`, import.meta.url), 'utf8'));
  } catch {
    throw new Error(`Read or create a valid ${configPath} before running integration tests.`);
  }
}

function baseUrl(value, field) {
  const url = typeof value === 'string' ? URL.parse(value) : null;
  if (!url?.hostname || url.username || url.password || url.search || url.hash || url.pathname !== '/') {
    throw new Error(`${field} must be a base URL without credentials, a path, a query or a fragment.`);
  }
  return url;
}

function host(url) {
  return url.hostname.replace(/\.$/, '');
}

function verifyConfig(environment, config, production) {
  const api = baseUrl(config?.API_BASE_URL, 'API_BASE_URL');
  const supabase = baseUrl(config?.SUPABASE_URL, 'SUPABASE_URL');
  const productionApi = baseUrl(production?.API_BASE_URL, 'Production API_BASE_URL');
  const productionSupabase = baseUrl(production?.SUPABASE_URL, 'Production SUPABASE_URL');
  const key = config?.SUPABASE_PUBLISHABLE_KEY;

  const usesProduction = host(api) === host(productionApi) ||
    host(supabase) === host(productionSupabase) ||
    key === production?.SUPABASE_PUBLISHABLE_KEY;
  if (usesProduction) {
    throw new Error('Integration tests require an isolated API and Supabase project. Production configuration was rejected.');
  }
  if (supabase.protocol !== 'https:' || supabase.port || !/^[a-z0-9]+\.supabase\.co$/.test(supabase.hostname)) {
    throw new Error('SUPABASE_URL must be the https://<project-ref>.supabase.co URL of the isolated project.');
  }
  if (typeof key !== 'string' || !/^sb_publishable_[A-Za-z0-9_-]+$/.test(key)) {
    throw new Error('SUPABASE_PUBLISHABLE_KEY must be a publishable key for the isolated project.');
  }
  if (environment === 'local' && (!localApiHosts.has(host(api)) || !['http:', 'https:'].includes(api.protocol))) {
    throw new Error('The local integration API must use an HTTP(S) loopback host or the emulator host 10.0.2.2.');
  }
  if (environment === 'staging' && (api.protocol !== 'https:' || localApiHosts.has(host(api)))) {
    throw new Error('The staging integration API must use its deployed HTTPS URL.');
  }
}

function main([environment, option, ...extra]) {
  const configPath = configs.get(environment);
  if (!configPath || extra.length || (option !== undefined && option !== '--check')) {
    throw new Error(usage);
  }

  verifyConfig(environment, readConfig(configPath), readConfig('config/production.json'));
  console.log(`Integration configuration verified for ${environment}.`);
  if (option === '--check') return;

  const args = ['test', '--no-pub', `--dart-define-from-file=${configPath}`, 'integration_test'];
  const options = { cwd: fileURLToPath(new URL('../', import.meta.url)), stdio: 'inherit' };
  const run = process.platform === 'win32'
    ? spawnSync(`flutter ${args.join(' ')}`, { ...options, shell: true })
    : spawnSync('flutter', args, options);
  if (run.error) throw run.error;
  process.exitCode = run.status ?? 1;
}

try {
  main(process.argv.slice(2));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
