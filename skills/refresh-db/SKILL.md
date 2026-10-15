---
name: refresh-db
description: Refresh the TifoXR vault database notes from the dev database (read-only) and update stored procedure logic notes. Run only when the user asks for it.
disable-model-invocation: true
argument-hint: "[--only name,name or prefix_*]  [--check]  [--from-file schema.sql]"
---

Refresh the TifoXR database notes. The source is always the **dev** database, the single source of truth. The vault folder is `$TIFOXR_VAULT`.

## Step 0: permission
This connects to the dev database, so it needs the user's permission every time. The user invoked this skill, which is their request; Claude Code will still show an approval prompt for the script and the user approves it there. If **you** think a refresh is needed (for example the notes look stale), do NOT run it. Ask the user first, say why, and wait for a yes.

## Step 1: run the refresh
Run this with the Bash tool and show the user the summary it prints:

```
node "$TIFOXR_VAULT/tools/refresh-db.js" $ARGUMENTS
```

- If `$TIFOXR_VAULT` is empty, stop and tell the user to run `node tools/setup.js` in their vault clone (it sets the variable).
- Do NOT open or print the database access file. The script reads it itself and signs in to dev through `sqlcmd` with the Entra email and password stored there.
- The script only sends SELECT queries on catalog views. If it prints a WARNING that the login can change data, repeat that warning to the user once; it does not stop the refresh.
- If it cannot connect, report the error, then continue the task using the existing notes and say clearly that they may be stale, quoting the "as of" date in `05-Database/DB Current State.md`. Offer `--from-file <schema script>` as a fallback.
- `--check` only tests the connection.

## Step 2: explain what changed
The script prints a short report: totals (before, now, change), then the names of new, changed and removed tables and procedures, then logic note counts and anything that needs attention. It lists names only, never procedure bodies. The terminal copy is capped; the full lists are in `05-Database/DB Refresh Report.md`.

Keep your context small: show the report to the user and add a few plain words on it. Do NOT open the report file, the `.sql` procedure files or the domain notes unless the user asks or the current task needs a specific one.
- point out tables under NEEDS ATTENTION (they need adding to `tools/domains.json`)
- if it says "BASELINE SWITCH", explain that this happens once, on the first live run after a script-file baseline: tables are compared in full, procedure bodies are not compared on that run, and from the next run on they are

## Step 3: procedure business-logic notes
The summary shows procedures that are STALE, or NEW or changed with no summary. Write or update logic notes only for procedures that are STALE, new or changed AND matched by `--only` or touched by the current task. Do NOT summarise every procedure that has "not written yet" unless the user explicitly asks for all.

For each procedure to document:
1. Run the refresh again with `--only <proc_name>` (asking permission again) to get its `sql_hash` and SQL file path.
2. Read `05-Database/Procedures/<proc_name>.sql` in full.
3. Find where the backend calls it (grep the repositories and services).
4. Write or replace its section in `05-Database/Logic/DB Logic <Domain>.md` (create the file if missing, with frontmatter: `title`, `category: database`, `agent_hint`, `index_tier: lazy`, `type: database-logic`, `status: live`, `generated: false`, `owner: syed`, `last_verified`, `review_by`). The hash comment goes on the line right after the heading:

```
### proc_name
<!-- sql_hash: abc123def456 -->
- Purpose: one or two plain sentences
- Inputs: parameters and what they mean
- Reads: tables
- Writes: tables
- Business rules: rules the SQL enforces
- Side effects and errors: what else changes, what it raises on failure
- Called from: backend file and method, or "not found"
- Written by Claude from the SQL text on <date>. Not verified by a person.
```

Write only what the SQL shows. If something is unclear, write "unclear from SQL". Never put secrets or data values in a note.

## Step 4: finish
Ask permission once more and run the refresh without `--only`, so the structure notes show the new Logic status. Then regenerate the session index with `node "$TIFOXR_VAULT/tools/build-index.js"` and run `node "$TIFOXR_VAULT/tools/check-vault.js"`. Give a short summary: as-of date, what changed, which logic notes were written, and what is still stale or missing.

Use only plain ASCII in everything you write.
