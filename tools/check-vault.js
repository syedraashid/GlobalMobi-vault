#!/usr/bin/env node
'use strict';
/*
 * check-vault: validate the vault. Exit 1 when there are errors, 0 otherwise (warnings do not fail).
 *   - every note has the required frontmatter and valid values
 *   - hand-written notes have a review_by date; stale ones warn
 *   - wiki links resolve; no non-ASCII characters; no obvious secrets
 *   - vault-index.md is current and within budget
 *   - plugin manifest, hooks and skills are well formed (when present)
 *
 *   node tools/check-vault.js
 */
const fs = require('fs');
const path = require('path');
const V = require('./lib/vault');

const errors = [], warnings = [];
const err = (m) => errors.push(m);
const warn = (m) => warnings.push(m);
const REQUIRED = ['title', 'category', 'status', 'owner', 'last_verified', 'agent_hint', 'index_tier'];
const WARN_CHARS = 24000, ERR_CHARS = 40000;
const today = new Date().toISOString().slice(0, 10);

const notes = V.loadNotes();
const files = V.allFiles();
const known = new Set(files.filter((f) => f.endsWith('.md')).map((f) => path.basename(f, '.md')));

// ---- notes
for (const n of notes) {
  if (!n.fm) { err(`${n.path}: missing frontmatter`); continue; }
  for (const k of REQUIRED) if (!n.fm[k]) err(`${n.path}: missing frontmatter field "${k}"`);
  if (n.fm.title && n.fm.title !== n.name) err(`${n.path}: title "${n.fm.title}" does not match the file name`);
  if (n.fm.category && !V.CATEGORIES.includes(n.fm.category)) err(`${n.path}: category "${n.fm.category}" is not one of ${V.CATEGORIES.join(', ')}`);
  if (n.fm.status && !V.STATUSES.includes(n.fm.status)) err(`${n.path}: status "${n.fm.status}" is not one of ${V.STATUSES.join(', ')}`);
  if (n.fm.index_tier && !['eager', 'lazy'].includes(n.fm.index_tier)) err(`${n.path}: index_tier must be eager or lazy`);
  if (n.fm.agent_hint && n.fm.agent_hint.length > 200) warn(`${n.path}: agent_hint is ${n.fm.agent_hint.length} characters; keep it under 200`);
  const generated = n.fm.generated === 'true';
  if (!generated) {
    if (!n.fm.review_by) err(`${n.path}: hand-written note needs review_by (yyyy-mm-dd)`);
    else if (!/^\d{4}-\d{2}-\d{2}$/.test(n.fm.review_by)) err(`${n.path}: review_by must be yyyy-mm-dd`);
    else if (n.fm.review_by < today) warn(`${n.path}: review_by ${n.fm.review_by} has passed; re-check the note against the code and update it`);
    if (n.text.length > ERR_CHARS) err(`${n.path}: ${n.text.length} characters is over the ${ERR_CHARS} limit; split the note`);
    else if (n.text.length > WARN_CHARS) warn(`${n.path}: ${n.text.length} characters; consider splitting`);
  }
}

// ---- links
for (const n of notes.concat(files.filter((f) => f.startsWith('99-Templates/') && f.endsWith('.md')).map((f) => ({ path: f, text: fs.readFileSync(path.join(V.ROOT, f), 'utf8') })))) {
  if (n.path.startsWith('99-Templates/')) continue; // templates hold placeholder links
  for (const m of n.text.matchAll(/\[\[([^\]|#\\]+)/g)) {
    const t = m[1].trim();
    if (!known.has(t)) err(`${n.path}: broken link [[${t}]]`);
  }
}

// ---- ASCII and secrets (everything except generated procedure SQL and git internals)
const TEXT_EXT = /\.(md|js|json|yml|yaml|sh|txt|gitignore)$/i;
const SECRET = [/AccountKey=[A-Za-z0-9+\/=]{20,}/, /SharedAccessSignature=\S{20,}/, /sk_(live|test)_[A-Za-z0-9]{10,}/, /-----BEGIN [A-Z ]*PRIVATE KEY-----/, /Password=[^;\s"'`<>{}]{4,}/i];
for (const f of files) {
  if (f.startsWith('05-Database/Procedures/') || f.startsWith('05-Database/_state/') || f.startsWith('_proposals/') || f === 'package-lock.json') continue;
  const base = path.basename(f);
  if (!TEXT_EXT.test(base) && base !== '.gitignore') continue;
  const text = fs.readFileSync(path.join(V.ROOT, f), 'utf8');
  if (/[^\x00-\x7F]/.test(text)) {
    const line = text.split('\n').findIndex((l) => /[^\x00-\x7F]/.test(l)) + 1;
    err(`${f}: non-ASCII character on line ${line} (use plain hyphens, straight quotes, no arrows)`);
  }
  for (const re of SECRET) if (re.test(text)) { err(`${f}: looks like it contains a secret (${re.source.slice(0, 24)}...)`); break; }
}

// ---- index
{
  const eager = notes.filter((n) => n.fm && n.fm.index_tier === 'eager');
  const out = V.buildIndex(notes);
  if (eager.length > V.MAX_EAGER) err(`vault-index: ${eager.length} eager notes, limit ${V.MAX_EAGER}`);
  if (out.length > V.MAX_INDEX_CHARS) err(`vault-index: ${out.length} characters, limit ${V.MAX_INDEX_CHARS}`);
  const f = path.join(V.ROOT, 'vault-index.md');
  const have = fs.existsSync(f) ? fs.readFileSync(f, 'utf8').replace(/\r\n/g, '\n') : '';
  if (have !== out) err('vault-index.md is out of date. Run: node tools/build-index.js');
}

// ---- plugin pieces
const readJson = (r) => { try { return JSON.parse(fs.readFileSync(path.join(V.ROOT, r), 'utf8')); } catch (e) { err(`${r}: invalid JSON (${e.message})`); return null; } };
if (fs.existsSync(path.join(V.ROOT, '.claude-plugin/plugin.json'))) {
  const p = readJson('.claude-plugin/plugin.json');
  if (p) {
    if (!p.name) err('plugin.json: missing name');
    for (const s of p.skills || []) {
      const sk = path.join(V.ROOT, s, 'SKILL.md');
      if (!fs.existsSync(sk)) { err(`plugin.json: skill ${s} has no SKILL.md`); continue; }
      const fmx = V.parseFrontmatter(fs.readFileSync(sk, 'utf8'));
      if (!fmx || !fmx.fm.name || !fmx.fm.description) err(`${s}/SKILL.md: needs name and description in frontmatter`);
    }
    if (p.hooks) {
      const h = readJson(p.hooks.replace(/^\.\//, ''));
      if (h) {
        for (const entries of Object.values(h.hooks || {})) for (const e of entries) for (const hk of e.hooks || []) {
          for (const a of hk.args || []) {
            const m = String(a).match(/\$\{CLAUDE_PLUGIN_ROOT\}\/(.+)$/);
            if (m && !fs.existsSync(path.join(V.ROOT, m[1]))) err(`hooks: script ${m[1]} does not exist`);
          }
        }
      }
    }
  }
  readJson('.claude-plugin/marketplace.json');
}

for (const w of warnings) console.log('WARN  ' + w);
for (const e of errors) console.log('ERROR ' + e);
console.log(`\ncheck-vault: ${notes.length} notes, ${errors.length} error(s), ${warnings.length} warning(s)`);
process.exit(errors.length ? 1 : 0);
