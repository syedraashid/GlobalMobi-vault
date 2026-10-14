#!/usr/bin/env node
'use strict';
/*
 * build-index: generate vault-index.md, the small index a SessionStart hook shows to Claude.
 * Only notes marked index_tier: eager get a "when to read" line; the rest are listed by title.
 *
 *   node tools/build-index.js           write vault-index.md
 *   node tools/build-index.js --check   fail if vault-index.md is out of date or over budget
 */
const fs = require('fs');
const path = require('path');
const V = require('./lib/vault');

const check = process.argv.includes('--check');
const notes = V.loadNotes();
const eager = notes.filter((n) => n.fm && n.fm.index_tier === 'eager');
const out = V.buildIndex(notes);
const file = path.join(V.ROOT, 'vault-index.md');
let bad = false;

if (eager.length > V.MAX_EAGER) {
  console.error(`ERROR: ${eager.length} eager notes, the limit is ${V.MAX_EAGER}. To promote a note, demote another (set index_tier: lazy).`);
  bad = true;
}
if (out.length > V.MAX_INDEX_CHARS) {
  console.error(`ERROR: index is ${out.length} characters, the limit is ${V.MAX_INDEX_CHARS}. Shorten agent_hint lines or demote notes.`);
  bad = true;
}
if (check) {
  const have = fs.existsSync(file) ? fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n') : '';
  if (have !== out) { console.error('ERROR: vault-index.md is out of date. Run: node tools/build-index.js'); bad = true; }
  else console.log(`vault-index.md is current (${out.length} characters, ${eager.length} eager notes).`);
  process.exit(bad ? 1 : 0);
}
if (bad) process.exit(1);
fs.writeFileSync(file, out);
console.log(`Wrote vault-index.md: ${out.length} characters, ${eager.length} eager notes, ${notes.length - eager.length} lazy.`);
