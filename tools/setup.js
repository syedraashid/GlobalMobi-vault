#!/usr/bin/env node
'use strict';
/*
 * setup: one-time setup of the TifoXR vault on a machine.
 *
 *   node tools/setup.js [--backend <path>] [--cms <path>] [--no-plugin] [--dry-run]
 *
 * It does the manual steps for you, and never overwrites an existing file:
 *   1. checks Node, git, sqlcmd and the Claude CLI
 *   2. sets TIFOXR_VAULT (the location of this vault) for new terminals
 *   3. creates the database access file from a template and locks it to your user (values stay empty)
 *   4. backend clone: creates migration/, ignores it locally, adds a CLAUDE.md if missing
 *   5. CMS clone: adds a CLAUDE.md if missing
 *   6. turns on the vault's git pre-commit check
 *   7. installs the TifoXR Claude Code plugin from this folder
 *   8. runs the hook and vault self-tests
 * Nothing here reads or prints secrets.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const opt = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : null; };
const DRY = flag('--dry-run');
const VAULT = path.resolve(__dirname, '..');
const win = process.platform === 'win32';

const results = [];
const say = (tag, msg) => { results.push(tag); console.log(`[${tag}] ${msg}`); };
const run = (cmd, a, o) => spawnSync(cmd, a, Object.assign({ encoding: 'utf8', windowsHide: true }, o || {}));
const which = (cmd, a) => { const r = run(cmd, a || ['--version']); return r.status === 0 && !r.error; };

console.log(`TifoXR vault setup${DRY ? ' (dry run: nothing will be changed)' : ''}\nVault: ${VAULT}\n`);

// 1. prerequisites
const nodeMajor = parseInt(process.versions.node.split('.')[0], 10);
say(nodeMajor >= 18 ? 'ok' : 'FAIL', `Node ${process.versions.node}${nodeMajor >= 18 ? '' : ' (need 18 or newer)'}`);
say(which('git') ? 'ok' : 'FAIL', 'git ' + (which('git') ? 'found' : 'not found'));
const hasSqlcmd = which('sqlcmd', ['-?']);
say(hasSqlcmd ? 'ok' : 'todo', hasSqlcmd ? 'sqlcmd found' : 'sqlcmd not found: install the SQL Server command line tools. It is only needed for the database refresh.');
const hasClaude = which('claude', ['--version']) || (win && run('claude', ['--version'], { shell: true }).status === 0);
say(hasClaude ? 'ok' : 'todo', hasClaude ? 'Claude CLI found' : 'Claude CLI not found: install Claude Code to use the plugin.');

// 2. vault location variable
if (process.env.TIFOXR_VAULT && path.resolve(process.env.TIFOXR_VAULT) === VAULT) {
  say('skip', 'TIFOXR_VAULT already set to this folder');
} else if (DRY) {
  say('dry', `would set TIFOXR_VAULT=${VAULT}`);
} else if (win) {
  const r = run('setx', ['TIFOXR_VAULT', VAULT]);
  say(r.status === 0 ? 'ok' : 'FAIL', r.status === 0 ? 'TIFOXR_VAULT set for new terminals (open a new terminal or restart Claude Code to pick it up)' : 'could not set TIFOXR_VAULT: ' + (r.stderr || r.error));
} else {
  say('todo', `add this line to your shell profile: export TIFOXR_VAULT="${VAULT}"`);
}

// 3. access file
function accessEnvPath() {
  if (process.env.TIFOXR_ACCESS_ENV) return process.env.TIFOXR_ACCESS_ENV;
  if (process.env.ACCESS_ENV_FILE) return process.env.ACCESS_ENV_FILE;
  const legacy = 'C:\\TifoXR\\tifoxr-access.env';
  if (fs.existsSync(legacy)) return legacy;
  return path.join(os.homedir(), '.tifoxr', 'access.env');
}
const envFile = accessEnvPath();
if (fs.existsSync(envFile)) {
  say('skip', `access file already exists (${envFile}); not touched`);
} else if (DRY) {
  say('dry', `would create ${envFile} from the template and lock it to your user`);
} else {
  fs.mkdirSync(path.dirname(envFile), { recursive: true });
  fs.copyFileSync(path.join(__dirname, 'templates', 'access.env.template'), envFile);
  try { fs.chmodSync(envFile, 0o600); } catch (_) { /* not supported on Windows */ }
  if (win) run('icacls', [envFile, '/inheritance:r', '/grant:r', `${process.env.USERNAME}:(F)`]);
  say('ok', `created ${envFile} (empty values, owner-only). Fill in SQL_DEV_SERVER, SQL_DEV_DATABASE, SQL_DEV_USER and SQL_DEV_PASSWORD.`);
}

// 4 and 5. code repos
const sibling = (name) => path.join(path.dirname(VAULT), name);
const repoPath = (cli, envName, folder) => { const c = opt(cli) || process.env[envName] || sibling(folder); return fs.existsSync(path.join(c, '.git')) ? path.resolve(c) : null; };
function placeClaudeMd(repo, template, label) {
  const dest = path.join(repo, 'CLAUDE.md');
  if (fs.existsSync(dest)) { say('skip', `${label}: CLAUDE.md already exists; not touched`); return; }
  if (DRY) { say('dry', `${label}: would create CLAUDE.md`); return; }
  fs.copyFileSync(path.join(__dirname, 'templates', template), dest);
  say('ok', `${label}: created CLAUDE.md (untracked; add it to the repo by pull request if you want teammates to get it)`);
}
const backend = repoPath('--backend', 'TIFOXR_BACKEND', 'TifoXRCoreWebAPI');
if (!backend) {
  say('todo', 'backend clone not found next to the vault. Run again with --backend <path> (or set TIFOXR_BACKEND).');
} else {
  const exclude = path.join(backend, '.git', 'info', 'exclude');
  const has = fs.existsSync(exclude) && /^\/migration\/\s*$/m.test(fs.readFileSync(exclude, 'utf8'));
  if (DRY) say('dry', `backend: would create migration/ and ignore it in ${exclude}`);
  else {
    fs.mkdirSync(path.join(backend, 'migration'), { recursive: true });
    if (!has) { fs.mkdirSync(path.dirname(exclude), { recursive: true }); fs.appendFileSync(exclude, '\n# Local SQL migration files (TifoXR vault decision ADR-0002)\n/migration/\n'); }
    say('ok', `backend: migration/ ready and ignored locally (${backend})`);
  }
  placeClaudeMd(backend, 'backend-CLAUDE.md', 'backend');
}
const cms = repoPath('--cms', 'TIFOXR_CMS', 'TifoXRContentManager');
if (!cms) say('todo', 'CMS clone not found next to the vault. Run again with --cms <path> (or set TIFOXR_CMS).');
else placeClaudeMd(cms, 'cms-CLAUDE.md', 'CMS');

// 6. pre-commit check
if (fs.existsSync(path.join(VAULT, '.git'))) {
  if (DRY) say('dry', 'would run: git config core.hooksPath .githooks');
  else { const r = run('git', ['-C', VAULT, 'config', 'core.hooksPath', '.githooks']); say(r.status === 0 ? 'ok' : 'FAIL', 'vault pre-commit check enabled (build-index and check-vault run before each commit)'); }
} else say('skip', 'this folder is not a git repo; pre-commit check not enabled');

// 7. plugin
function claude(a) { return run('claude', a, { shell: win }); }
if (flag('--no-plugin')) say('skip', 'plugin install skipped (--no-plugin)');
else if (!hasClaude) say('todo', `install the plugin later with:  claude plugin marketplace add "${VAULT}"  then  claude plugin install tifoxr@tifoxr-plugins`);
else if (DRY) say('dry', `would run: claude plugin marketplace add "${VAULT}" and claude plugin install tifoxr@tifoxr-plugins`);
else {
  const ml = claude(['plugin', 'marketplace', 'list']);
  if (!/tifoxr-plugins/.test(ml.stdout || '')) {
    const a = claude(['plugin', 'marketplace', 'add', VAULT]);
    say(a.status === 0 ? 'ok' : 'FAIL', 'marketplace add: ' + ((a.stdout || a.stderr || '').trim().split('\n').pop() || 'done'));
  } else say('skip', 'marketplace tifoxr-plugins already added');
  const pl = claude(['plugin', 'list']);
  if (!/tifoxr@tifoxr-plugins/.test(pl.stdout || '')) {
    const i = claude(['plugin', 'install', 'tifoxr@tifoxr-plugins']);
    say(i.status === 0 ? 'ok' : 'FAIL', 'plugin install: ' + ((i.stdout || i.stderr || '').trim().split('\n').pop() || 'done'));
  } else say('skip', 'plugin tifoxr already installed');
}

// 8. self-tests
for (const [label, cmd, a] of [
  ['guard hook self-test', 'node', [path.join(VAULT, 'hooks', 'scripts', 'guard.js'), '--selftest']],
  ['session index hook self-test', 'node', [path.join(VAULT, 'hooks', 'scripts', 'inject-index.js'), '--selftest']],
  ['vault check', 'node', [path.join(VAULT, 'tools', 'check-vault.js')]],
]) {
  if (DRY) { say('dry', `would run ${label}`); continue; }
  const r = run(cmd, a, { env: Object.assign({}, process.env, { TIFOXR_VAULT: VAULT }) });
  say(r.status === 0 ? 'ok' : 'FAIL', label);
}

console.log('\nStill to do by hand:');
console.log(`  1. Fill in the SQL values in ${envFile} (server, database, your Entra email and password).`);
console.log('  2. Make sure your IP is allowed on the Azure SQL firewall and your account can read the dev database.');
console.log('  3. Open a NEW terminal, start Claude Code in a TifoXR repo, and you should see the vault index at the start.');
console.log('  4. To test the connection later: run the refresh skill with --check and approve the prompt.');
const bad = results.filter((r) => r === 'FAIL').length;
console.log(`\nDone: ${results.filter((r) => r === 'ok').length} ok, ${results.filter((r) => r === 'skip').length} skipped, ${results.filter((r) => r === 'todo').length} to do, ${bad} failed.`);
process.exit(bad ? 1 : 0);
