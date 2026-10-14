---
name: db-context
description: Use when a task involves the TifoXR database: tables, columns, keys, stored procedures, queries, data questions or a schema change. Loads only the database notes the task needs and checks how fresh they are. Do not use for tasks that do not touch the database.
---

# Database context, only when needed

The database notes are large (21 notes and 471 stored-procedure files), so they are **not** loaded at session start. Load only what this task needs. The vault folder is `$TIFOXR_VAULT` (also printed at the start of a TifoXR session). All paths below are inside it.

## Steps
1. Read `05-Database/DB Current State.md`. Note the "as of" date and the domain table.
2. Pick the one or two domains the task is about and read only `05-Database/DB <Domain>.md` for those. For a single table, read just its section (`### table_name`). Do **not** read every domain note and do not browse the whole `Procedures/` folder.
3. For a stored procedure, read `05-Database/Procedures/<name>.sql`. If `05-Database/Logic/` has a summary for it and the domain note marks it `ok`, you may use the summary; if it is `STALE` or `missing`, read the SQL.
4. **Freshness.** If the notes are more than about 7 days old, or the task depends on exact columns, **ask the user**: "The database notes are N days old. Do you want to run /refresh-db?" Then wait. Never run the refresh yourself; it connects to the dev database and needs the user's approval each time. If they say no, carry on and say plainly that the answer may be out of date, quoting the as-of date.
5. If the task changes the database, use the `sql-migration` skill. Never hand over loose SQL.
6. In your answer, say which notes you used and the as-of date.

## Limits
- The notes describe the **dev** database only. Test and prod may differ.
- Table purposes in the notes are inferred from names and are not verified.
- Table lists for procedures come from reading the SQL text, so dynamic SQL is missed.
