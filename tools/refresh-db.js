#!/usr/bin/env node
'use strict';
/*
 * refresh-db: read the TifoXR DEV database (READ-ONLY) through sqlcmd, refresh the vault's DB notes,
 * and report what changed since the last run. The dev database is the single source of truth.
 *
 *   node tools/refresh-db.js                      refresh from the dev database
 *   node tools/refresh-db.js --only payment_*     also print details for matching tables/procedures
 *   node tools/refresh-db.js --check              test the connection and the login only, change nothing
 *   node tools/refresh-db.js --from-file x.sql    use an SSMS schema script instead of a live connection
 *
 * Only SELECT statements on catalog views are ever sent. Credentials come from the access env file and
 * are never printed or written. The file is found in this order: TIFOXR_ACCESS_ENV, ACCESS_ENV_FILE,
 * the older C:\\TifoXR\\tifoxr-access.env if it exists, then ~/.tifoxr/access.env.
 * The vault to update is TIFOXR_VAULT if set, otherwise the folder that holds this script.
 * Env keys: SQL_DEV_SERVER, SQL_DEV_DATABASE, SQL_DEV_USER (Entra email), SQL_DEV_PASSWORD.
 * Optional: SQL_DEV_TRUST_CERT=1 (self-signed certificates), SQLCMD_PATH.
 * If SQL_DEV_USER is empty, Windows authentication is used.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

// The vault to write into. TIFOXR_VAULT wins. Without it, use the folder this script sits in, but refuse
// when that folder is a plugin cache copy, because notes written there would be lost on the next update.
const IN_PLUGIN_CACHE = /[\\/]\.claude[\\/]plugins[\\/]/i.test(__dirname);
if (IN_PLUGIN_CACHE && !process.env.TIFOXR_VAULT) {
  console.error('ERROR: this script is running from the Claude plugin cache. Set TIFOXR_VAULT to your vault clone (run tools/setup.js once) so the notes are written there.');
  process.exit(1);
}
const VAULT = process.env.TIFOXR_VAULT ? path.resolve(process.env.TIFOXR_VAULT) : path.resolve(__dirname, '..');
const DBDIR = path.join(VAULT, '05-Database');
const STATE_DIR = path.join(DBDIR, '_state');
const PROC_DIR = path.join(DBDIR, 'Procedures');
const LOGIC_DIR = path.join(DBDIR, 'Logic');
const DOMAINS_FILE = fs.existsSync(path.join(VAULT, 'tools', 'domains.json')) ? path.join(VAULT, 'tools', 'domains.json') : path.join(__dirname, 'domains.json');
const DOMAINS = JSON.parse(fs.readFileSync(DOMAINS_FILE, 'utf8'));

// ------------------------------------------------------------------ args
function parseArgs(a) {
  const o = { only: null, fromFile: null, check: false, help: false };
  for (let i = 0; i < a.length; i++) {
    const x = a[i];
    if (x === '--only') o.only = String(a[++i] || '').split(',').map(s => s.trim()).filter(Boolean);
    else if (x === '--from-file') o.fromFile = a[++i];
    else if (x === '--check') o.check = true;
    else if (x === '--help' || x === '-h') o.help = true;
    else { console.error('Unknown option: ' + x); process.exit(2); }
  }
  return o;
}
const args = parseArgs(process.argv.slice(2));
const fail = (m) => { console.error('ERROR: ' + m); process.exit(1); };
const matchOnly = (name) => !args.only || args.only.some(p => new RegExp('^' + p.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*') + '$', 'i').test(name));


// ------------------------------------------------------------------ helpers
const sha = (s) => crypto.createHash('sha1').update(s).digest('hex').slice(0, 12);
const normSql = (s) => String(s || '').replace(/\r\n/g, '\n').replace(/[ \t]+$/gm, '').trim();
const clean = (n) => n.replace(/[\[\]]/g, '').trim();
const esc = (s) => String(s).replace(/\|/g, '\\|');
function writeIfChanged(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  if (fs.existsSync(file) && fs.readFileSync(file, 'utf8') === content) return false;
  fs.writeFileSync(file, content);
  return true;
}
function readSqlFile(f) {
  const buf = fs.readFileSync(f);
  if (buf[0] === 0xff && buf[1] === 0xfe) return buf.slice(2).toString('utf16le');
  return buf.toString('utf8').replace(/^\uFEFF/, '');
}
function accessEnvPath() {
  if (process.env.TIFOXR_ACCESS_ENV) return process.env.TIFOXR_ACCESS_ENV;
  if (process.env.ACCESS_ENV_FILE) return process.env.ACCESS_ENV_FILE;
  const legacy = 'C:\\TifoXR\\tifoxr-access.env';
  if (fs.existsSync(legacy)) return legacy;
  return path.join(os.homedir(), '.tifoxr', 'access.env');
}
function loadEnvFile() {
  const f = accessEnvPath();
  if (!fs.existsSync(f)) fail('Access env file not found: ' + f + '. Run tools/setup.js to create a template, then fill in the SQL values.');
  if (process.platform === 'win32') {
    try {
      const acl = require('child_process').execFileSync('icacls', [f], { encoding: 'utf8' });
      if (/\\Users:|Everyone:|Authenticated Users:/i.test(acl)) console.error('WARNING: the access env file is readable by other users on this machine. Lock it down: icacls "' + f + '" /inheritance:r /grant:r "%USERNAME%:(F)"');
    } catch (_) { /* permission check is best effort */ }
  }
  const env = {};
  for (const line of fs.readFileSync(f, 'utf8').split(/\r?\n/)) {
    if (/^\s*#/.test(line)) continue;
    const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return env;
}

// ------------------------------------------------------------------ model: from SSMS script
function fromFile(file) {
  const txt = readSqlFile(file);
  const batches = txt.split(/^\s*GO\s*$/m);
  const tables = {}, procs = {}, modules = {};
  for (const b of batches) {
    let m = b.match(/CREATE\s+TABLE\s+\[(\w+)\]\.\[([^\]]+)\]\s*\(([\s\S]*)\)\s*(?:ON\s+\[\w+\][\s\S]*)?$/);
    if (m && /^\s*(?:SET[^\n]*\n\s*)*CREATE\s+TABLE/i.test(b)) {
      const name = m[1] === 'dbo' ? m[2] : m[1] + '.' + m[2];
      const cols = [];
      for (let line of m[3].split('\n')) {
        line = line.trim().replace(/,$/, '');
        if (/^CONSTRAINT/i.test(line) || /^PRIMARY KEY/i.test(line)) continue;
        const cm = line.match(/^\[([^\]]+)\]\s+(\[[^\]]+\](?:\([^)]*\))?)(.*)$/);
        if (cm) {
          cols.push({ n: cm[1], t: cm[2].replace(/[\[\]\s]/g, '').toLowerCase(), null: !/NOT NULL/i.test(cm[3]), id: /IDENTITY/i.test(cm[3]) });
        } else {
          const cc = line.match(/^\[([^\]]+)\]\s+AS\s*\(/i);
          if (cc) cols.push({ n: cc[1], t: 'computed', null: true, id: false });
        }
      }
      const bp = m[3].match(/PRIMARY KEY\s*(?:CLUSTERED|NONCLUSTERED)?\s*\(([^)]*)\)/i);
      const pk = bp ? bp[1].split(',').map(x => clean(x.trim().split(/\s+/)[0])) : [];
      tables[name] = { cols, pk, fks: [], uniques: [] };
      continue;
    }
    if (/^\s*(?:\/\*[\s\S]*?\*\/\s*)?CREATE\s+(?:OR\s+ALTER\s+)?(PROC|PROCEDURE|VIEW|FUNCTION|TRIGGER)\s/im.test(b)) {
      const mm = b.match(/CREATE\s+(?:OR\s+ALTER\s+)?(PROC(?:EDURE)?|VIEW|FUNCTION|TRIGGER)\s+\[(\w+)\]\.\[([^\]]+)\]/i);
      if (mm) {
        const body = b.replace(/^\s*\/\*{5,}[\s\S]*?\*{5,}\/\s*/, '');
        const kind = mm[1].toUpperCase().startsWith('PROC') ? 'P' : mm[1].toUpperCase();
        const nm = mm[2] === 'dbo' ? mm[3] : mm[2] + '.' + mm[3];
        if (kind === 'P') procs[nm] = { sql: body }; else modules[nm] = { type: kind, sql: body };
      }
    }
  }
  const tn = (s) => s;
  let m;
  const fkRe = /ALTER TABLE \[(\w+)\]\.\[([^\]]+)\]\s+(?:WITH \w+\s+)?ADD\s+(?:CONSTRAINT\s+\[([^\]]+)\]\s+)?FOREIGN KEY\s*\(([^)]*)\)\s*REFERENCES\s+\[(\w+)\]\.\[([^\]]+)\]\s*\(([^)]*)\)/g;
  while ((m = fkRe.exec(txt))) {
    const t = tn(m[1] === 'dbo' ? m[2] : m[1] + '.' + m[2]);
    if (tables[t]) tables[t].fks.push({ cols: m[4].split(',').map(clean), ref: m[5] === 'dbo' ? m[6] : m[5] + '.' + m[6], rcols: m[7].split(',').map(clean) });
  }
  const pkRe = /ALTER TABLE \[(\w+)\]\.\[([^\]]+)\]\s+ADD\s+(?:CONSTRAINT\s+\[[^\]]+\]\s+)?PRIMARY KEY[^(]*\(([^)]*)\)/g;
  while ((m = pkRe.exec(txt))) {
    const t = m[1] === 'dbo' ? m[2] : m[1] + '.' + m[2];
    if (tables[t] && !tables[t].pk.length) tables[t].pk = m[3].split(',').map(x => clean(x.trim().split(/\s+/)[0]));
  }
  const uqRe = /ALTER TABLE \[(\w+)\]\.\[([^\]]+)\]\s+ADD\s+(?:CONSTRAINT\s+\[[^\]]+\]\s+)?UNIQUE[^(]*\(([^)]*)\)/g;
  while ((m = uqRe.exec(txt))) {
    const t = m[1] === 'dbo' ? m[2] : m[1] + '.' + m[2];
    if (tables[t]) tables[t].uniques.push(m[3].split(',').map(x => clean(x.trim().split(/\s+/)[0])));
  }
  const indexCount = (txt.match(/CREATE\s+(?:UNIQUE\s+)?(?:NON)?CLUSTERED\s+(?:COLUMNSTORE\s+)?INDEX/gi) || []).length;
  const hd = txt.match(/Object:\s+Database\s+\[([^\]]+)\]\s+Script Date:\s+(\d\d)-(\d\d)-(\d{4})\s+(\d\d:\d\d:\d\d)/);
  const asOf = hd ? `${hd[4]}-${hd[3]}-${hd[2]}T${hd[5]}` : fs.statSync(file).mtime.toISOString();
  const ed = txt.match(/EDITION = '([^']+)'.*?MAXSIZE = (\d+ \w+)/);
  const cl = txt.match(/COMPATIBILITY_LEVEL = (\d+)/);
  return { tables, procs, modules, indexCount, meta: { kind: 'file', source: 'script file ' + path.basename(file), db: hd ? hd[1] : 'unknown', asOf, edition: ed ? ed[1] + ', max ' + ed[2] : '', compat: cl ? cl[1] : '' } };
}

// ------------------------------------------------------------------ model: live dev database, read-only, via sqlcmd
function fmtType(typ, maxLen, prec, scale) {
  const t = typ.toLowerCase();
  if (['char', 'varchar', 'binary', 'varbinary'].includes(t)) return t + '(' + (maxLen === -1 ? 'max' : maxLen) + ')';
  if (['nchar', 'nvarchar'].includes(t)) return t + '(' + (maxLen === -1 ? 'max' : maxLen / 2) + ')';
  if (['decimal', 'numeric'].includes(t)) return t + '(' + prec + ',' + scale + ')';
  if (['datetime2', 'datetimeoffset', 'time'].includes(t)) return t + '(' + scale + ')';
  return t;
}

// Every statement below is a SELECT on catalog views. Rows are tagged so the output can be parsed.
// Procedure text is sent in 2000-character chunks with CR, LF and TAB replaced by markers, because
// sqlcmd wraps long lines and cannot carry raw line breaks inside one row.
const CHUNK = 2000;
const CATALOG_SQL = `SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SELECT CONCAT('M|', DB_NAME(), '|', CONVERT(nvarchar(100), DATABASEPROPERTYEX(DB_NAME(), 'Edition')), '|', CONVERT(nvarchar(100), DATABASEPROPERTYEX(DB_NAME(), 'ServiceObjective')), '|', (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME()), '|', CONVERT(varchar(19), SYSUTCDATETIME(), 126), '|', ISNULL(IS_MEMBER('db_owner'), 0), '|', ISNULL(IS_MEMBER('db_datawriter'), 0), '|', ISNULL(IS_MEMBER('db_ddladmin'), 0));
GO
@@CATALOG@@`;
const TABLE_SQL = `SELECT CONCAT('T|', s.name COLLATE DATABASE_DEFAULT, '|', t.name COLLATE DATABASE_DEFAULT, '|', c.column_id, '|', c.name COLLATE DATABASE_DEFAULT, '|', ty.name COLLATE DATABASE_DEFAULT, '|', c.max_length, '|', c.precision, '|', c.scale, '|', c.is_nullable, '|', c.is_identity, '|', c.is_computed) FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.types ty ON ty.user_type_id = c.user_type_id WHERE t.is_ms_shipped = 0 ORDER BY s.name COLLATE DATABASE_DEFAULT, t.name COLLATE DATABASE_DEFAULT, c.column_id;
GO
SELECT CONCAT('K|', s.name COLLATE DATABASE_DEFAULT, '|', t.name COLLATE DATABASE_DEFAULT, '|', kc.type COLLATE DATABASE_DEFAULT, '|', kc.name COLLATE DATABASE_DEFAULT, '|', ic.key_ordinal, '|', c.name COLLATE DATABASE_DEFAULT) FROM sys.key_constraints kc JOIN sys.tables t ON t.object_id = kc.parent_object_id JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.index_columns ic ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id WHERE t.is_ms_shipped = 0 AND ic.is_included_column = 0 ORDER BY s.name COLLATE DATABASE_DEFAULT, t.name COLLATE DATABASE_DEFAULT, kc.name COLLATE DATABASE_DEFAULT, ic.key_ordinal;
GO
SELECT CONCAT('F|', fk.object_id, '|', ps.name COLLATE DATABASE_DEFAULT, '|', pt.name COLLATE DATABASE_DEFAULT, '|', pc.name COLLATE DATABASE_DEFAULT, '|', rs.name COLLATE DATABASE_DEFAULT, '|', rt.name COLLATE DATABASE_DEFAULT, '|', rc.name COLLATE DATABASE_DEFAULT, '|', fkc.constraint_column_id) FROM sys.foreign_keys fk JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id JOIN sys.tables pt ON pt.object_id = fk.parent_object_id JOIN sys.schemas ps ON ps.schema_id = pt.schema_id JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id JOIN sys.tables rt ON rt.object_id = fk.referenced_object_id JOIN sys.schemas rs ON rs.schema_id = rt.schema_id JOIN sys.columns rc ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id ORDER BY fk.object_id, fkc.constraint_column_id;
GO
SELECT CONCAT('I|', COUNT(*)) FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id WHERE i.is_primary_key = 0 AND i.is_unique_constraint = 0 AND i.type > 0 AND i.is_hypothetical = 0 AND t.is_ms_shipped = 0;
GO
SELECT CONCAT('D|', o.type COLLATE DATABASE_DEFAULT, '|', s.name COLLATE DATABASE_DEFAULT, '|', o.name COLLATE DATABASE_DEFAULT, '|', nn.n, '|', CASE WHEN m.definition IS NULL THEN 'N' ELSE 'Y' END, '|', REPLACE(REPLACE(REPLACE(SUBSTRING(m.definition COLLATE DATABASE_DEFAULT, nn.n * ${CHUNK} + 1, ${CHUNK}), CHAR(13), N'{{CR}}'), CHAR(10), N'{{LF}}'), CHAR(9), N'{{TAB}}'), '#EOL#') FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id JOIN sys.schemas s ON s.schema_id = o.schema_id JOIN (SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM sys.all_objects a CROSS JOIN sys.all_objects b) nn ON nn.n * ${CHUNK} < ISNULL(DATALENGTH(m.definition) / 2, 1) WHERE o.is_ms_shipped = 0 AND o.type COLLATE DATABASE_DEFAULT IN ('P', 'V', 'FN', 'IF', 'TF', 'TR') ORDER BY o.type COLLATE DATABASE_DEFAULT, o.name COLLATE DATABASE_DEFAULT, nn.n;
GO
`;
const META_ONLY_SQL = CATALOG_SQL.replace('@@CATALOG@@', '');
const FULL_SQL = CATALOG_SQL.replace('@@CATALOG@@', TABLE_SQL);
// Safety net: the script must contain no statement that could change anything.
for (const s of [META_ONLY_SQL, FULL_SQL]) {
  if (/\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|EXEC|EXECUTE|TRUNCATE|MERGE|GRANT|REVOKE|DENY|BACKUP|RESTORE|SHUTDOWN|INTO)\b/i.test(s.replace(/'[^']*'/g, "''"))) throw new Error('read-only guard: the query script contains a forbidden keyword');
}

function runSqlcmd(script, E) {
  const server = E.SQL_DEV_SERVER, database = E.SQL_DEV_DATABASE, user = E.SQL_DEV_USER, password = E.SQL_DEV_PASSWORD || '';
  if (!server || !database) fail('SQL_DEV_SERVER and SQL_DEV_DATABASE are empty in the access env file. Fill them in, or use --from-file.');
  if (user && !password) fail('SQL_DEV_USER is set but SQL_DEV_PASSWORD is empty in the access env file.');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'refresh-db-'));
  const inF = path.join(dir, 'q.sql'), outF = path.join(dir, 'out.txt');
  try {
    fs.writeFileSync(inF, script);
    const a = ['-S', server, '-d', database, '-l', '30', '-t', '900', '-b', '-u', '-w', '65534', '-y', '0', '-s', '|', '-i', inF, '-o', outF];
    if (user) a.push('-G', '-U', user, '-N'); else a.push('-E');
    if (/^(1|true|yes)$/i.test(E.SQL_DEV_TRUST_CERT || '')) a.push('-C');
    const r = require('child_process').spawnSync(E.SQLCMD_PATH || 'sqlcmd', a, { env: Object.assign({}, process.env, { SQLCMDPASSWORD: password }), encoding: 'utf8', timeout: 1200000, windowsHide: true, maxBuffer: 64 * 1024 * 1024 });
    const scrub = (s) => (password ? String(s || '').split(password).join('***') : String(s || ''));
    let text = '';
    if (fs.existsSync(outF)) {
      const buf = fs.readFileSync(outF);
      text = (buf[0] === 0xff && buf[1] === 0xfe) ? buf.slice(2).toString('utf16le') : buf.toString('utf8');
    }
    if (r.error) throw new Error('Could not run sqlcmd (' + (E.SQLCMD_PATH || 'sqlcmd') + '): ' + r.error.message);
    if (r.status !== 0) {
      const lines = (scrub(text) + '\n' + scrub(r.stderr) + '\n' + scrub(r.stdout)).split(/\r?\n/).filter(l => l.trim() && !/^[A-Z]\|/.test(l)).slice(0, 12);
      throw new Error('sqlcmd failed (exit ' + r.status + '):\n  ' + lines.join('\n  '));
    }
    return { text, auth: user ? 'Microsoft Entra (user and password)' : 'Windows authentication' };
  } finally { try { fs.rmSync(dir, { recursive: true, force: true }); } catch (_) { } }
}

function parseCatalog(text, source) {
  const unesc = (s) => s.replace(/\{\{CR\}\}/g, '\r').replace(/\{\{LF\}\}/g, '\n').replace(/\{\{TAB\}\}/g, '\t');
  const nm = (s, n) => (s === 'dbo' ? n : s + '.' + n);
  const tables = {}, uq = {}, fkm = {}, defs = {};
  let meta = null, indexCount = 0;
  for (const raw of text.split(/\r?\n/)) {
    if (!/^[MTKFID]\|/.test(raw)) continue;
    const line = raw.startsWith('D|') ? raw : raw.replace(/\s+$/, '');
    const f = line.split('|');
    switch (f[0]) {
      case 'M': meta = { db: f[1], edition: [f[2], f[3]].filter(x => x && x !== 'NULL').join(' / '), compat: f[4], utc: f[5], owner: f[6] === '1', writer: f[7] === '1', ddl: f[8] === '1' }; break;
      case 'T': {
        const n = nm(f[1], f[2]);
        (tables[n] = tables[n] || { cols: [], pk: [], fks: [], uniques: [] }).cols.push({ n: f[4], t: f[10 + 1] === '1' ? 'computed' : fmtType(f[5], parseInt(f[6], 10), f[7], f[8]), null: f[9] === '1', id: f[10] === '1' });
        break;
      }
      case 'K': {
        const t = tables[nm(f[1], f[2])]; if (!t) break;
        if (f[3] === 'PK') t.pk.push(f[6]);
        else { const k = f[1] + '.' + f[2] + '.' + f[4]; (uq[k] = uq[k] || { t, cols: [] }).cols.push(f[6]); }
        break;
      }
      case 'F': { const k = f[1]; (fkm[k] = fkm[k] || { t: nm(f[2], f[3]), ref: nm(f[5], f[6]), cols: [], rcols: [] }); fkm[k].cols.push(f[4]); fkm[k].rcols.push(f[7]); break; }
      case 'I': indexCount = parseInt(f[1], 10) || 0; break;
      case 'D': {
        const dtype = f[1].trim();
        const key = dtype + '|' + nm(f[2], f[3]);
        const d = (defs[key] = defs[key] || { type: dtype, name: nm(f[2], f[3]), chunks: [], readable: f[5] === 'Y' });
        let chunk = f.slice(6).join('|');
        chunk = chunk.replace(/#EOL#\s*$/, '');
        d.chunks[parseInt(f[4], 10)] = unesc(chunk);
        break;
      }
    }
  }
  if (!meta) fail('sqlcmd returned no data (is the database name right, and does the login have access?).');
  for (const u of Object.values(uq)) u.t.uniques.push(u.cols);
  for (const x of Object.values(fkm)) if (tables[x.t]) tables[x.t].fks.push({ cols: x.cols, ref: x.ref, rcols: x.rcols });
  const procs = {}, modules = {};
  let unreadable = 0;
  for (const d of Object.values(defs)) {
    const sql = d.readable ? d.chunks.map(c => c || '').join('') : '-- definition not readable (encrypted or no VIEW DEFINITION permission)';
    if (!d.readable) unreadable++;
    if (d.type === 'P') procs[d.name] = { sql }; else modules[d.name] = { type: d.type, sql };
  }
  const risky = [meta.owner && 'db_owner', meta.writer && 'db_datawriter', meta.ddl && 'db_ddladmin'].filter(Boolean);
  return { tables, procs, modules, indexCount, unreadable, risky, meta: { kind: 'live', source, db: meta.db, asOf: meta.utc, edition: meta.edition, compat: meta.compat } };
}

// ------------------------------------------------------------------ analysis
function analyse(model) {
  const T = model.tables;
  const names = Object.keys(T).sort((a, b) => a.localeCompare(b));
  // domain assignment
  const domainOf = {};
  for (const d of DOMAINS.domains) for (const t of d.tables) domainOf[t] = d.title;
  const unassigned = [];
  for (const n of names) {
    if (domainOf[n]) continue;
    const rule = DOMAINS.prefixRules.find(([p]) => n.startsWith(p));
    if (rule) domainOf[n] = rule[1]; else { domainOf[n] = 'Unassigned'; unassigned.push(n); }
  }
  const outFk = {}, inFk = {};
  for (const n of names) for (const fk of T[n].fks) (inFk[fk.ref] = inFk[fk.ref] || []).push({ from: n, cols: fk.cols });
  // procs: tables read/written (best effort from SQL text)
  const tset = new Set(names);
  const pinfo = {};
  const bare = (s) => s.replace(/^\[?dbo\]?\./i, '').replace(/[\[\]]/g, '');
  for (const [p, o] of Object.entries(model.procs)) {
    const sqlText = o.sql.replace(/--[^\n]*/g, ' ').replace(/\/\*[\s\S]*?\*\//g, ' ');
    const reads = new Set(), writes = new Set();
    for (const r of sqlText.matchAll(/\b(?:FROM|JOIN)\s+((?:\[?\w+\]?\.)?\[?\w+\]?)/gi)) { const t = bare(r[1]); if (tset.has(t)) reads.add(t); }
    for (const r of sqlText.matchAll(/\b(?:INSERT\s+INTO|UPDATE|MERGE(?:\s+INTO)?|DELETE\s+FROM|DELETE)\s+((?:\[?\w+\]?\.)?\[?\w+\]?)/gi)) { const t = bare(r[1]); if (tset.has(t)) writes.add(t); }
    const first = [...writes][0] || [...reads][0];
    pinfo[p] = { reads: [...reads].sort(), writes: [...writes].sort(), domain: first ? domainOf[first] : 'Unclassified', hash: sha(normSql(o.sql)) };
  }
  return { names, domainOf, unassigned, inFk, pinfo };
}

// ------------------------------------------------------------------ state + diff
function buildState(model, an, env) {
  const tables = {};
  for (const n of an.names) {
    const t = model.tables[n];
    const cols = {};
    for (const c of t.cols) cols[c.n] = c.t + '|' + (c.null ? 'null' : 'notnull') + (c.id ? '|identity' : '');
    tables[n] = { cols, order: t.cols.map(c => c.n), pk: t.pk, fks: t.fks.map(f => f.cols.join(',') + '>' + f.ref + '(' + f.rcols.join(',') + ')').sort(), uq: t.uniques.map(u => u.join(',')).sort() };
  }
  const procs = {};
  for (const [p, i] of Object.entries(an.pinfo)) procs[p] = i.hash;
  const modules = {};
  for (const [m, o] of Object.entries(model.modules)) modules[m] = { type: o.type, h: sha(normSql(o.sql)) };
  return { env, kind: model.meta.kind, source: model.meta.source, db: model.meta.db, asOf: model.meta.asOf, tables, procs, modules };
}
function diffState(prev, cur, opts) {
  opts = opts || {};
  const d = { tablesNew: [], tablesGone: [], tablesChanged: [], procsNew: [], procsGone: [], procsChanged: [], modNew: [], modGone: [], modChanged: [] };
  if (!prev) return null;
  for (const n of Object.keys(cur.tables)) {
    if (!prev.tables[n]) { d.tablesNew.push(n); continue; }
    const a = prev.tables[n], b = cur.tables[n], ch = { name: n, added: [], removed: [], changed: [], notes: [] };
    for (const c of Object.keys(b.cols)) { if (!(c in a.cols)) ch.added.push(c + ' ' + b.cols[c].replace('|notnull', ' NOT NULL').replace('|null', ' NULL').replace('|identity', ' IDENTITY')); else if (a.cols[c] !== b.cols[c]) { const f = (v) => v.replace('|notnull', ' NOT NULL').replace('|null', ' NULL').replace('|identity', ' IDENTITY'); ch.changed.push(`${c}: ${f(a.cols[c])} to ${f(b.cols[c])}`); } }
    for (const c of Object.keys(a.cols)) if (!(c in b.cols)) ch.removed.push(c);
    if (JSON.stringify(a.pk) !== JSON.stringify(b.pk)) ch.notes.push('primary key changed');
    const fa = new Set(a.fks), fb = new Set(b.fks);
    for (const f of fb) if (!fa.has(f)) ch.notes.push('FK added: ' + f);
    for (const f of fa) if (!fb.has(f)) ch.notes.push('FK removed: ' + f);
    if (JSON.stringify(a.uq) !== JSON.stringify(b.uq)) ch.notes.push('unique constraints changed');
    if (ch.added.length || ch.removed.length || ch.changed.length || ch.notes.length) d.tablesChanged.push(ch);
  }
  for (const n of Object.keys(prev.tables)) if (!cur.tables[n]) d.tablesGone.push(n);
  for (const p of Object.keys(cur.procs)) { if (!(p in prev.procs)) d.procsNew.push(p); else if (!opts.procsByNameOnly && prev.procs[p] !== cur.procs[p]) d.procsChanged.push(p); }
  for (const p of Object.keys(prev.procs)) if (!(p in cur.procs)) d.procsGone.push(p);
  const pm = prev.modules || {};
  for (const m of Object.keys(cur.modules)) { if (!pm[m]) d.modNew.push(m); else if (!opts.procsByNameOnly && pm[m].h !== cur.modules[m].h) d.modChanged.push(m); }
  for (const m of Object.keys(pm)) if (!cur.modules[m]) d.modGone.push(m);
  return d;
}
const diffEmpty = (d) => d && Object.values(d).every(v => !v.length);

// ------------------------------------------------------------------ logic note status
function scanLogic() {
  const found = {}; // proc -> { hash, domainNote }
  if (!fs.existsSync(LOGIC_DIR)) return found;
  for (const f of fs.readdirSync(LOGIC_DIR)) {
    if (!f.endsWith('.md')) continue;
    const txt = fs.readFileSync(path.join(LOGIC_DIR, f), 'utf8');
    for (const m of txt.matchAll(/^###\s+(\S+)\s*\n\s*<!--\s*sql_hash:\s*([0-9a-f]+)\s*-->/gm)) found[m[1]] = { hash: m[2], note: f.replace(/\.md$/, '') };
  }
  return found;
}

// ------------------------------------------------------------------ note writers
const dTitle = (t) => 'DB ' + t;
function fm(meta, extra, title, hint) {
  const head = title ? `title: "${title}"\ncategory: database\nagent_hint: "${hint}"\nindex_tier: lazy\n` : '';
  return `---\n${head}type: database\nstatus: live\nenvironment: dev\nside: shared\nowner: syed\nsource: "${meta.source}"\nsnapshot_as_of: ${meta.asOf}\nlast_verified: ${meta.asOf.slice(0, 10)}\ngenerated: true\n${extra || ''}tags: [database, side/shared]\n---\n\n`;
}
function writeNotes(model, an, logic) {
  const T = model.tables, { names, domainOf, inFk, pinfo } = an;
  const link = (t) => (domainOf[t] ? `[[${dTitle(domainOf[t])}#${t}|${t}]]` : t);
  const titles = [...DOMAINS.domains.map(d => d.title)];
  if (an.unassigned.length) titles.push('Unassigned');
  const written = [];
  const logicStatus = (p) => { const l = logic[p]; if (!l) return 'missing'; return l.hash === pinfo[p].hash ? 'ok' : 'STALE'; };
  const domDesc = Object.fromEntries(DOMAINS.domains.map(d => [d.title, d.description]));
  domDesc['Unassigned'] = 'Tables not yet mapped to a domain. Add them to tools/domains.json (tables list or prefixRules).';
  for (const title of titles) {
    const ts = names.filter(n => domainOf[n] === title);
    let o = fm(model.meta, '', dTitle(title), `Load when the task reads or changes tables or stored procedures in the ${title} area.`);
    o += `# ${dTitle(title)}\n\n${domDesc[title] || ''}\n\nPart of [[DB Current State]]. Generated from: ${model.meta.source}, as of ${model.meta.asOf}. Tables: ${ts.length}. Purposes are inferred from names and are **not verified**. Do not hand-edit: the next refresh overwrites this note.\n\n`;
    const edges = new Set();
    for (const t of ts) for (const fk of T[t].fks) edges.add(`  "${t}" }o--|| "${fk.ref}" : "${fk.cols.join(',')}"`);
    for (const t of ts) for (const f of (inFk[t] || [])) if (!ts.includes(f.from)) edges.add(`  "${f.from}" }o--|| "${t}" : "${f.cols.join(',')}"`);
    if (edges.size && edges.size <= 120) o += '## Relationships\n\n```mermaid\nerDiagram\n' + [...edges].sort().join('\n') + '\n```\n\n';
    else if (edges.size) o += `## Relationships\n\n${edges.size} foreign-key edges: too many for one diagram. See each table's lists below.\n\n`;
    o += '## Tables\n\n';
    for (const t of ts) {
      const x = T[t];
      o += `### ${t}\n\nPK: ${x.pk.length ? x.pk.map(c => '`' + c + '`').join(', ') : '**none**'}. Columns: ${x.cols.length}.\n\n| Column | Type | Null | Notes |\n|---|---|---|---|\n`;
      for (const c of x.cols) {
        const fk = x.fks.find(f => f.cols.includes(c.n));
        const notes = [x.pk.includes(c.n) ? 'PK' : '', c.id ? 'identity' : '', fk ? `FK to ${fk.ref}` : ''].filter(Boolean).join(', ');
        o += `| ${esc(c.n)} | ${esc(c.t)} | ${c.null ? 'yes' : 'no'} | ${notes} |\n`;
      }
      o += '\n';
      if (x.fks.length) o += 'References: ' + x.fks.map(f => `${f.cols.join(',')} to ${link(f.ref)}.${f.rcols.join(',')}`).join('; ') + '\n\n';
      const refd = inFk[t] || [];
      if (refd.length) o += 'Referenced by: ' + refd.map(f => `${link(f.from)} (${f.cols.join(',')})`).join(', ') + '\n\n';
      if (x.uniques.length) o += 'Unique: ' + x.uniques.map(u => u.join('+')).join('; ') + '\n\n';
    }
    const ps = Object.keys(pinfo).filter(p => pinfo[p].domain === title).sort();
    o += `## Stored procedures (${ps.length})\n\nGrouped by the first table each procedure writes (or reads if it writes none). Table lists come from the SQL text and miss dynamic SQL. SQL text: \`05-Database/Procedures/<name>.sql\`. Logic column: ok (summary matches current SQL), STALE (SQL changed since the summary), missing (no summary yet).\n\n`;
    if (ps.length) {
      o += '| Procedure | Writes | Reads | Logic |\n|---|---|---|---|\n';
      for (const p of ps) {
        const i = pinfo[p], st = logicStatus(p);
        const nameCell = logic[p] ? `[[${logic[p].note}#${p}\\|${p}]]` : p;
        o += `| ${nameCell} | ${i.writes.join(', ')} | ${i.reads.filter(r => !i.writes.includes(r)).join(', ')} | ${st} |\n`;
      }
    }
    if (writeIfChanged(path.join(DBDIR, dTitle(title) + '.md'), o)) written.push(dTitle(title));
  }
  if (!an.unassigned.length) { const f = path.join(DBDIR, 'DB Unassigned.md'); if (fs.existsSync(f)) fs.unlinkSync(f); }
  // unclassified procs
  const un = Object.keys(pinfo).filter(p => pinfo[p].domain === 'Unclassified').sort();
  let u = fm(model.meta, '', 'DB Unclassified Procedures', 'Load to find stored procedures that touch no table.') + `# DB Unclassified Procedures\n\nProcedures with no table reference found in their SQL text (they may call other procedures or use dynamic SQL). Count: ${un.length}. Part of [[DB Current State]].\n\n`;
  for (const p of un) u += `- ${p} (logic: ${logicStatus(p)})\n`;
  writeIfChanged(path.join(DBDIR, 'DB Unclassified Procedures.md'), u);
  // catalog
  let c = fm(model.meta, '', 'DB Table Catalog', 'Load to find which domain a table belongs to and its foreign key and procedure counts.') + '# DB Table Catalog\n\nAll tables. Part of [[DB Current State]].\n\n| Table | Domain | Columns | FK out | FK in | Procs touching |\n|---|---|---|---|---|---|\n';
  const touch = {};
  for (const [p, i] of Object.entries(pinfo)) for (const t of new Set([...i.reads, ...i.writes])) touch[t] = (touch[t] || 0) + 1;
  for (const t of names) c += `| ${link(t)} | ${domainOf[t]} | ${T[t].cols.length} | ${T[t].fks.length} | ${(inFk[t] || []).length} | ${touch[t] || 0} |\n`;
  writeIfChanged(path.join(DBDIR, 'DB Table Catalog.md'), c);
  // procedure + module SQL files
  fs.mkdirSync(PROC_DIR, { recursive: true });
  const safe = (n) => n.replace(/[^A-Za-z0-9_.-]/g, '_');
  const keep = new Set();
  let nonAscii = 0;
  for (const [p, o] of Object.entries(model.procs)) {
    const fn = safe(p) + '.sql'; keep.add(fn);
    const body = normSql(o.sql) + '\n';
    if (/[^\x00-\x7F]/.test(body)) nonAscii++;
    writeIfChanged(path.join(PROC_DIR, fn), body);
  }
  for (const [m, o] of Object.entries(model.modules)) { const fn = safe(m) + '.' + o.type + '.sql'; keep.add(fn); writeIfChanged(path.join(PROC_DIR, fn), normSql(o.sql) + '\n'); }
  const removed = [];
  for (const f of fs.readdirSync(PROC_DIR)) if (f.endsWith('.sql') && !keep.has(f)) { fs.unlinkSync(path.join(PROC_DIR, f)); removed.push(f); }
  return { nonAscii, removedFiles: removed };
}

function logicCounts(an, logic) {
  const r = { ok: 0, stale: [], missing: [] };
  for (const p of Object.keys(an.pinfo)) {
    const l = logic[p];
    if (!l) r.missing.push(p); else if (l.hash === an.pinfo[p].hash) r.ok++; else r.stale.push(p);
  }
  return r;
}

// ------------------------------------------------------------------ main
(async function main() {
  if (args.help) { console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0].replace(/^[^\n]*\n\/\*\n?/, '')); return; }
  const env = 'dev';
  let model;
  if (args.fromFile) {
    if (!fs.existsSync(args.fromFile)) fail('File not found: ' + args.fromFile);
    model = fromFile(args.fromFile);
  } else {
    const E = loadEnvFile();
    try {
      if (args.check) {
        const r = runSqlcmd(META_ONLY_SQL, E);
        const m = parseMeta(r.text);
        console.log(`Connected to database "${m.db}" using ${r.auth}.`);
        console.log(m.risky.length ? 'WARNING: this login is a member of ' + m.risky.join(', ') + ', so it can change data. The refresh sends only SELECT queries, but a read-only login is safer.' : 'Login looks read-only (not in db_owner, db_datawriter or db_ddladmin).');
        return;
      }
      const r = runSqlcmd(FULL_SQL, E);
      model = parseCatalog(r.text, 'live dev database via sqlcmd (' + r.auth + ')');
    } catch (e) { fail(e.message); }
  }

  const an = analyse(model);
  const state = buildState(model, an, env);
  fs.mkdirSync(STATE_DIR, { recursive: true });
  const stateFile = path.join(STATE_DIR, env + '.json');
  const prev = fs.existsSync(stateFile) ? JSON.parse(fs.readFileSync(stateFile, 'utf8')) : null;
  const switched = !!prev && (prev.kind || 'file') !== state.kind;
  const diff = diffState(prev, state, { procsByNameOnly: switched });
  const T = model.tables;
  const counts = { tables: an.names.length, cols: an.names.reduce((a, n) => a + T[n].cols.length, 0), fks: an.names.reduce((a, n) => a + T[n].fks.length, 0), procs: Object.keys(model.procs).length, modules: Object.keys(model.modules).length, indexes: model.indexCount };
  const out = [];
  const P = (s) => out.push(s);
  P(`Refresh DB: DEV  |  source: ${model.meta.source}  |  as of ${model.meta.asOf}`);
  P(`Tables ${counts.tables}, columns ${counts.cols}, foreign keys ${counts.fks}, stored procedures ${counts.procs}, other modules ${counts.modules}, indexes ${counts.indexes}`);
  if (model.risky && model.risky.length) P(`WARNING: this login is a member of ${model.risky.join(', ')} and could change data. The refresh sends only SELECT queries.`);
  if (model.unreadable) P(`WARNING: ${model.unreadable} definition(s) could not be read (grant VIEW DEFINITION to this login).`);

  const logic = scanLogic();
  const res = writeNotes(model, an, logic);
  const lc = logicCounts(an, logic);

  if (!prev) P('\nFirst refresh: baseline created (no earlier state to compare with).');
  else if (switched) P(`\nBaseline switched from ${prev.kind || 'file'} (${prev.asOf}) to ${state.kind}. Tables are compared in full below. Procedures are compared by name only, and their fingerprints are reset, because the text a script holds and the text the database returns can differ slightly in whitespace.`);
  if (prev && diffEmpty(diff)) P(`\nNo changes since the last refresh (${prev.asOf}).`);
  else if (prev) { P(`\nChanges since the last refresh (${prev.asOf}):`); listDiff(P, diff, 'new', 'removed'); }
  if (res.removedFiles.length) P('Procedure files removed: ' + res.removedFiles.join(', '));
  if (an.unassigned.length) P(`\nUNASSIGNED tables (add to tools/domains.json): ${an.unassigned.join(', ')}`);

  const changedProcs = diff ? [...diff.procsNew, ...diff.procsChanged] : [];
  P(`\nProcedure logic notes: ${lc.ok} up to date, ${lc.stale.length} STALE, ${lc.missing.length} not written yet.`);
  if (lc.stale.length) P('STALE (SQL changed since the summary): ' + lc.stale.join(', '));
  const newMissing = changedProcs.filter(p => lc.missing.includes(p));
  if (newMissing.length) P('NEW or changed, no summary yet: ' + newMissing.join(', '));

  if (args.only) {
    P(`\nDetails for --only ${args.only.join(',')}:`);
    const mt = an.names.filter(matchOnly), mp = Object.keys(an.pinfo).filter(matchOnly).sort();
    if (!mt.length && !mp.length) P('  no table or procedure matched.');
    for (const t of mt) {
      const x = T[t];
      P(`  TABLE ${t} [${an.domainOf[t]}] PK(${x.pk.join(',')})`);
      for (const c of x.cols) P(`    ${c.n} ${c.t}${c.null ? '' : ' NOT NULL'}${c.id ? ' IDENTITY' : ''}`);
      for (const f of x.fks) P(`    FK ${f.cols.join(',')} to ${f.ref}(${f.rcols.join(',')})`);
    }
    for (const p of mp) {
      const i = an.pinfo[p], l = logic[p];
      P(`  PROC ${p} [${i.domain}] logic: ${!l ? 'missing' : l.hash === i.hash ? 'ok' : 'STALE'}  sql_hash: ${i.hash}`);
      P(`    file: 05-Database/Procedures/${p.replace(/[^A-Za-z0-9_.-]/g, '_')}.sql`);
      if (i.writes.length) P('    writes: ' + i.writes.join(', '));
      if (i.reads.length) P('    reads: ' + i.reads.filter(r => !i.writes.includes(r)).join(', '));
    }
  }

  writeIfChanged(stateFile, JSON.stringify(state, null, 1));
  const domainRows = [...DOMAINS.domains.map(d => d.title), ...(an.unassigned.length ? ['Unassigned'] : [])].map(t => {
    const nt = an.names.filter(n => an.domainOf[n] === t).length, np = Object.values(an.pinfo).filter(i => i.domain === t).length;
    return `| [[${dTitle(t)}]] | ${nt} | ${np} |`;
  });
  const now = new Date().toISOString().slice(0, 19) + 'Z';
  const cs = fm(model.meta, '', 'DB Current State', 'Load only when the task touches the database, tables or stored procedures. Check the as-of date and ask before refreshing.') + `# DB Current State\n\n**Read this first** before any development that touches the database. This is the **dev** database, the single source of truth.\n\n## Freshness\n| | |\n|---|---|\n| Environment | dev |\n| Source | ${model.meta.source} |\n| Database state as of | ${model.meta.asOf} |\n| Notes refreshed | ${now} |\n| Platform | ${model.meta.edition || 'n/a'}${model.meta.compat ? ', compatibility level ' + model.meta.compat : ''} |\n\n## Rule\nBefore database-related work, check the as-of date above. If the notes may be stale, **ask the user** whether to run \`/refresh-db\` (see [[DB Refresh Command]]). **Claude must not run the refresh without the user\'s permission.** If the refresh is not run, say the information may be stale and quote the date above. After a migration runs successfully on dev, ask the user to refresh again.\n\n## Size\nTables ${counts.tables}, columns ${counts.cols}, foreign keys ${counts.fks}, stored procedures ${counts.procs}, other modules (views, functions, triggers) ${counts.modules}, indexes ${counts.indexes}.\n\n## Domains\n| Domain | Tables | Procedures |\n|---|---|---|\n${domainRows.join('\n')}\n\nAlso: [[DB Table Catalog]], [[DB Unclassified Procedures]], [[DB Refresh Report]], [[DB Refresh Log]].\n\n## Stored procedure business logic\nSummaries live in \`05-Database/Logic/\`. Status now: ${lc.ok} up to date, ${lc.stale.length} stale, ${lc.missing.length} not written. Each summary carries the hash of the SQL it was written from, so a changed procedure shows as STALE. Do not trust a STALE or missing summary; read the SQL file in \`05-Database/Procedures/\`.\n\nHuman notes about the database (meaning, history): [[Database]].\n`;
  writeIfChanged(path.join(DBDIR, 'DB Current State.md'), cs);
  writeIfChanged(path.join(DBDIR, 'DB Refresh Report.md'), fm(model.meta, '', 'DB Refresh Report', 'Load to see what the last database refresh found.') + `# DB Refresh Report\n\nLatest run only. Written ${now}.\n\n\`\`\`\n${out.join('\n')}\n\`\`\`\n`);
  const logFile = path.join(DBDIR, 'DB Refresh Log.md');
  const summ = !prev ? 'baseline' : switched ? `baseline switched to ${state.kind}; tables +${diff.tablesNew.length}/-${diff.tablesGone.length}/~${diff.tablesChanged.length}, procs +${diff.procsNew.length}/-${diff.procsGone.length}` : diffEmpty(diff) ? 'no changes' : `tables +${diff.tablesNew.length}/-${diff.tablesGone.length}/~${diff.tablesChanged.length}, procs +${diff.procsNew.length}/-${diff.procsGone.length}/~${diff.procsChanged.length}`;
  const line = `| ${now} | dev | ${model.meta.asOf} | ${counts.tables} | ${counts.procs} | ${summ} |`;
  if (!prev || switched || !diffEmpty(diff) || !fs.existsSync(logFile)) {
    const log = fs.existsSync(logFile) ? fs.readFileSync(logFile, 'utf8') : fm(model.meta, '', 'DB Refresh Log', 'Load to see the history of database refreshes.') + '# DB Refresh Log\n\nOne line per refresh that found a change. Newest at the bottom. Details of each change are in git history of this vault.\n\n| Refreshed (UTC) | Env | DB state as of | Tables | Procs | Change |\n|---|---|---|---|---|---|\n';
    writeIfChanged(logFile, log.trimEnd() + '\n' + line + '\n');
  }
  if (res.nonAscii) P(`Note: ${res.nonAscii} procedure SQL file(s) contain non-ASCII characters (copied as-is from the database).`);
  console.log(out.join('\n'));
  console.log('\nNotes updated in 05-Database. Start from "DB Current State".');
})().catch(e => fail(e.stack || e.message));

function parseMeta(text) {
  const l = text.split(/\r?\n/).find(x => /^M\|/.test(x));
  if (!l) throw new Error('sqlcmd returned no data (is the database name right, and does the login have access?).');
  const f = l.split('|');
  return { db: f[1], risky: [f[6] === '1' && 'db_owner', f[7] === '1' && 'db_datawriter', f[8] === '1' && 'db_ddladmin'].filter(Boolean) };
}

function listDiff(P, d, newLbl, goneLbl) {
  if (!d || diffEmpty(d)) { P('  no differences.'); return; }
  if (d.tablesNew.length) P(`  Tables ${newLbl} (${d.tablesNew.length}): ${d.tablesNew.join(', ')}`);
  if (d.tablesGone.length) P(`  Tables ${goneLbl} (${d.tablesGone.length}): ${d.tablesGone.join(', ')}`);
  for (const t of d.tablesChanged) {
    P(`  Table changed: ${t.name}`);
    for (const c of t.added) P(`    + column ${c}`);
    for (const c of t.removed) P(`    - column ${c}`);
    for (const c of t.changed) P(`    ~ column ${c}`);
    for (const c of t.notes) P(`    ~ ${c}`);
  }
  if (d.procsNew.length) P(`  Procedures ${newLbl} (${d.procsNew.length}): ${d.procsNew.join(', ')}`);
  if (d.procsGone.length) P(`  Procedures ${goneLbl} (${d.procsGone.length}): ${d.procsGone.join(', ')}`);
  if (d.procsChanged.length) P(`  Procedures changed (${d.procsChanged.length}): ${d.procsChanged.join(', ')}`);
  if (d.modNew.length || d.modGone.length || d.modChanged.length) P(`  Other modules: new ${d.modNew.join(', ') || '-'}; removed ${d.modGone.join(', ') || '-'}; changed ${d.modChanged.join(', ') || '-'}`);
}
