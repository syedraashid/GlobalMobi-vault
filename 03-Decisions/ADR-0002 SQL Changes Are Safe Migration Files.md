---
title: "ADR-0002 SQL Changes Are Safe Migration Files"
category: decisions
agent_hint: "Load before writing any SQL change: migration file rules."
index_tier: lazy
review_by: 2027-01-12
type: decision
status: accepted
owner: syed
decided_on: 2026-10-14
last_verified: 2026-10-14
tags: [decision, database]
---

# ADR-0002 SQL Changes Are Safe Migration Files

## Decision
Every database change is written as a **migration file**, never as loose SQL run by hand. Each migration must:
1. **Check before it acts.** Create with a not-exists check, drop with an exists check, add columns and indexes only if missing. Running it twice changes nothing and raises no error.
2. **Run in one transaction.** On any error the whole migration rolls back, so the database is never left half changed.
3. **Verify before it commits.** It asserts the expected end state and fails (and rolls back) if the state is wrong.
4. **Live in the backend `migration` folder**, which is git-ignored.

## Where and how
- Folder: `C:\TifoXR\TifoXRCoreWebAPI\migration\`, git-ignored through the repo's local exclude list (`.git/info/exclude`), so it is ignored in this clone only.
- File name: `yyyyMMdd-HHmm-short-description.sql`.
- Claude writes migrations with the **`sql-migration` skill**, which holds the full rules and a template. It lives in this vault repo at `skills/sql-migration/` and is installed with the `tifoxr` plugin ([[Claude Setup]]).
- Run with `sqlcmd ... -b` so a failure stops the script and returns an error.
- After a migration succeeds on dev, the notes should be refreshed with `/refresh-db` so they match the database ([[DB Refresh Command]]). Claude must **ask the user first**; it never runs the refresh on its own.

## Consequences
- Migration files are **not in git, on purpose** (confirmed by syed 2026-10-14): no history, and not shared through the repo.
- Fixing a migration that already ran means writing a new file, not editing the old one.
- Statements that cannot run inside a transaction (for example `CREATE DATABASE`) go in a separate file, with that stated in its header.
