---
title: "DB Refresh Command"
category: database
agent_hint: "Load for how to run /refresh-db, its options and its limits."
index_tier: lazy
review_by: 2027-01-12
type: runbook
status: live
owner: syed
last_verified: 2026-10-14
tags: [runbook, database]
---

# DB Refresh Command

One command keeps the database notes current. The source is always the **dev database**, the single source of truth. Run it when you **start development**, and again **after your migration runs successfully on dev**.

## Run it
In Claude Code (with the plugin installed): `/tifoxr:refresh-db`. You invoke it; Claude cannot start it, and the guard hook asks you to approve the run.
From any terminal: `node "$TIFOXR_VAULT/tools/refresh-db.js"` (or the path to `tools/refresh-db.js` in your vault clone). `TIFOXR_VAULT` is set by `node tools/setup.js`.

| Option | Meaning |
|---|---|
| (none) | Read the whole dev database, refresh all notes, report only what changed |
| `--only payment_*` | Also print full details for matching tables and procedures. `*` is a wildcard. Comma-separate several. |
| `--check` | Test the connection and whether the login can write. Changes nothing. |
| `--from-file x.sql` | Use an SSMS schema script instead of a live connection (fallback) |

## What it does
1. Calls `sqlcmd` with the Entra email and password from `C:\TifoXR\tifoxr-access.env`, like `sqlcmd -G -U <email> -P <password>`. The password is passed through an environment variable, never on the command line, and is never printed.
2. Runs **SELECT-only** queries on the catalog in a single call: tables, columns, keys, indexes, and the SQL text of every procedure. Table data is never read. A built-in guard refuses to run if the query script contains anything that could change data.
3. Compares with the previous run (`05-Database/_state/dev.json`) and lists: new, removed and changed tables (column by column), and new, removed and changed procedures.
4. Rewrites the generated notes: `DB Current State`, one note per domain, `DB Table Catalog`, and one `.sql` file per procedure in `05-Database/Procedures/`.
5. Writes `DB Refresh Report` (latest run) and adds a line to `DB Refresh Log` when something changed.

It always reads everything (this is only metadata, so it is quick) and reports only the differences, so "new things" and "everything" are both covered without a mode switch.

## First live run
The first baseline came from a schema script. The text a script holds and the text the database returns can differ slightly in whitespace. So on the first live run the tool **compares tables in full but procedures by name only**, resets the procedure fingerprints, and says "Baseline switched". From the second run on it behaves normally.

## Stored procedure business logic
Notes in `05-Database/Logic/` explain what each procedure does. Each section stores the **hash of the SQL it was written from**. When the SQL changes, the refresh marks the section **STALE**, and the domain notes show ok, STALE or missing next to every procedure.

`/refresh-db` then has Claude read only the new, changed or STALE procedures that your task touches, and write or update their summaries. It does not write all of them unless you ask. A summary is written from the SQL text and is not verified by a person.

## Rules for Claude
- **Ask first.** Before database work, read [[DB Current State]] and check its "as of" date. If the notes may be stale, ask the user whether to run `/refresh-db`. Never run the refresh on your own: it connects to the dev database, so it needs the user's permission every time.
- A permission rule in the user settings (`permissions.ask`) also makes Claude Code prompt before any run of `tools/refresh-db.js`, so the approval is enforced and not only requested.
- Never trust a STALE or missing logic note. Read the SQL file.
- If the refresh is not run (declined or cannot run), say the notes may be stale and quote the date.

## Setup (one time)
0. On a new machine run `node tools/setup.js` first ([[New Machine Setup]]). It creates the access file and sets `TIFOXR_VAULT`.
1. In the access env file fill `SQL_DEV_SERVER`, `SQL_DEV_DATABASE`, `SQL_DEV_USER` (Entra email) and `SQL_DEV_PASSWORD`. See [[Access Setup]].
2. Needs `sqlcmd` on the PATH (a copy is installed with the SQL Server client tools). Override with `SQLCMD_PATH` in the env file if needed.
3. Test with `--check`. It prints the database name and warns if the login can write.

## Limits
- Table lists for procedures come from reading the SQL text, so dynamic SQL is missed.
- Needs `VIEW DEFINITION` on the database to read procedure text. Procedures it cannot read (encrypted, or no permission) are counted and warned about.
- Entra username and password sign-in does not work if the account requires MFA.
- It sees the database as it is. It cannot know what a table is for, so purposes in the notes are inferred from names.
- New tables are assigned to a domain by name prefix rules in `tools/domains.json`. Others are listed as UNASSIGNED until mapped.

## Testing status
Tested end to end against a SQL Server on the developer machine using temporary objects in `tempdb` (removed afterwards): tables, composite keys, foreign keys, identity and computed columns, views, an encrypted procedure, change detection, and exact round trip of a 13,600-character procedure with tabs, pipes and non-ASCII text. **Not yet tested against Azure SQL with Entra sign-in**, which needs the credentials above. Run `--check` first.
