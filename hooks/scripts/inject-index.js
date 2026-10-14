#!/usr/bin/env node
'use strict';
/*
 * inject-index: SessionStart hook. Prints a small TifoXR vault index so Claude knows what notes exist
 * and when to read them, without loading the notes themselves. Whatever this prints on stdout is added
 * to the session context.
 *
 * It only speaks when the session is inside TifoXR work (a folder whose path contains "tifoxr", the vault
 * itself, or a folder listed in TIFOXR_REPOS), so it adds nothing to unrelated projects.
 * It never fails a session: any problem prints nothing and exits 0.
 *
 *   node inject-index.js --selftest     prove the index can be found and print what would be injected
 */
const fs = require('fs');
const path = require('path');

const SELFTEST = process.argv.includes('--selftest');
const MAX_CHARS = 9500; // Claude Code truncates hook output near 10000 characters

function readStdin() {
  try { if (process.stdin.isTTY) return ''; return fs.readFileSync(0, 'utf8'); } catch (_) { return ''; }
}
const norm = (p) => String(p || '').replace(/\\/g, '/').toLowerCase().replace(/\/+$/, '');

function findVault() {
  const here = path.resolve(__dirname, '..', '..');
  const candidates = [process.env.TIFOXR_VAULT, process.env.CLAUDE_PLUGIN_ROOT, here].filter(Boolean);
  for (const c of candidates) if (fs.existsSync(path.join(c, 'vault-index.md'))) return path.resolve(c);
  return null;
}

function relevant(cwd, vault) {
  const c = norm(cwd);
  if (!c) return false;
  if (c.includes('tifoxr')) return true;
  if (vault && (c === norm(vault) || c.startsWith(norm(vault) + '/'))) return true;
  const extra = String(process.env.TIFOXR_REPOS || '').split(/[;,]/).map(norm).filter(Boolean);
  return extra.some((e) => c === e || c.startsWith(e + '/'));
}

function dbLine(vault) {
  try {
    const s = JSON.parse(fs.readFileSync(path.join(vault, '05-Database', '_state', 'dev.json'), 'utf8'));
    const d = new Date(s.asOf);
    const days = Math.max(0, Math.floor((Date.now() - d.getTime()) / 86400000));
    return `Database notes: dev schema as of ${String(s.asOf).slice(0, 10)} (${days} day${days === 1 ? '' : 's'} old). Read "05-Database/DB Current State.md" only when the task touches the database, tables or stored procedures.`;
  } catch (_) {
    return 'Database notes: not generated yet. Read nothing about the database until the user has run the refresh.';
  }
}

try {
  const vault = findVault();
  if (!vault) {
    process.stderr.write('inject-index: vault-index.md not found (set TIFOXR_VAULT)\n');
    process.exit(SELFTEST ? 1 : 0);
  }
  let cwd = '';
  if (!SELFTEST) {
    const raw = readStdin();
    try { cwd = JSON.parse(raw).cwd || ''; } catch (_) { cwd = ''; }
    if (!cwd) cwd = process.cwd();
    if (!relevant(cwd, vault)) process.exit(0);
  }
  const index = fs.readFileSync(path.join(vault, 'vault-index.md'), 'utf8').replace(/\r\n/g, '\n').replace(/^# .*\n\n(Generated .*\n\n)?/, '');
  let out = `TifoXR knowledge vault: ${vault}\nRead notes with the Read tool. Paths below are relative to that folder.\n\n${index.trimEnd()}\n\n${dbLine(vault)}\n\nStanding rules:\n- Never run the complete API test suite; run filtered tests only.\n- Every SQL change is a migration file: use the sql-migration skill.\n- Never open or print the database access file.\n- Never run the database refresh yourself; ask the user first.\n- The vault can be wrong. Check the code before relying on a note.\n`;
  if (out.length > MAX_CHARS) out = out.slice(0, MAX_CHARS - 40) + '\n[truncated]\n';
  process.stdout.write(out);
  process.exit(0);
} catch (e) {
  process.stderr.write('inject-index: ' + e.message + '\n');
  process.exit(SELFTEST ? 1 : 0);
}
