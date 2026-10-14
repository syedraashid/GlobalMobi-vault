#!/usr/bin/env node
'use strict';
/*
 * guard: PreToolUse hook for Bash and PowerShell commands. Enforces the team's standing rules:
 *   1. refresh-db.js           always ask the user first (it connects to the dev database)
 *   2. dotnet test             inside TifoXR work, deny unless filtered (ADR-0001: never the full suite)
 *   3. the database access file  deny commands that print, copy or source it
 * Reads the hook JSON on stdin and prints a permission decision as JSON. Any problem allows the command
 * (fails open), so a bug here can never break a session.
 *
 *   node guard.js --selftest     run built-in test cases
 */
const fs = require('fs');

function decide(command, cwd) {
  const cmd = String(command || '');
  const inTifoxr = /tifoxr/i.test(String(cwd || '') + ' ' + cmd);

  if (/refresh-db\.js/i.test(cmd)) {
    return { d: 'ask', r: 'The database refresh connects to the dev database. Confirm you want to run it now.' };
  }
  if (/(tifoxr-access\.env|[\\/]\.tifoxr[\\/]access\.env)/i.test(cmd) &&
      /(^|[\s;&|(])(cat|type|get-content|gc|more|less|head|tail|sed|awk|grep|rg|select-string|findstr|cp|copy|copy-item|out-file|source)\b/i.test(cmd)) {
    return { d: 'deny', r: 'The database access file holds credentials. Never print, copy or source it. The refresh script reads it by itself.' };
  }
  if (inTifoxr && /\bdotnet\s+test\b/i.test(cmd) && !/--filter\b/i.test(cmd) && !/--list-tests\b/i.test(cmd)) {
    return { d: 'deny', r: 'Team decision ADR-0001: never run the complete API test suite. Add --filter "FullyQualifiedName~YourTests" to run only the tests for the code you changed.' };
  }
  return null;
}

if (process.argv.includes('--selftest')) {
  const cases = [
    ['node C:/TifoXR/TifoXR-Vault/tools/refresh-db.js --check', '', 'ask'],
    ['node tools/refresh-db.js', 'C:/x', 'ask'],
    ['dotnet test TifoXRCoreWebAPI.Tests/TifoXRCoreWebAPI.Tests.csproj', 'C:/TifoXR/TifoXRCoreWebAPI', 'deny'],
    ['dotnet test --filter "FullyQualifiedName~BoothTests"', 'C:/TifoXR/TifoXRCoreWebAPI', null],
    ['dotnet test --list-tests', 'C:/TifoXR/TifoXRCoreWebAPI', null],
    ['dotnet test', 'C:/Projects/SomethingElse', null],
    ['cat C:/TifoXR/tifoxr-access.env', '', 'deny'],
    ['Get-Content ~/.tifoxr/access.env', '', 'deny'],
    ['icacls C:/TifoXR/tifoxr-access.env', '', null],
    ['git status', 'C:/TifoXR', null],
  ];
  let bad = 0;
  for (const [c, cwd, want] of cases) {
    const got = (decide(c, cwd) || {}).d || null;
    const ok = got === want;
    if (!ok) bad++;
    console.log((ok ? 'PASS ' : 'FAIL ') + JSON.stringify(c) + ' expected ' + want + ' got ' + got);
  }
  console.log(bad ? `${bad} failed` : 'all passed');
  process.exit(bad ? 1 : 0);
}

try {
  const raw = process.stdin.isTTY ? '' : fs.readFileSync(0, 'utf8');
  const j = JSON.parse(raw || '{}');
  const res = decide((j.tool_input || {}).command, j.cwd);
  if (res) {
    process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: res.d, permissionDecisionReason: res.r } }));
  }
} catch (_) { /* fail open */ }
process.exit(0);
