---
name: sql-migration
description: Use whenever you write or change any SQL that alters the TifoXR database: new or changed tables, columns, indexes, constraints, stored procedures, views, seed data or data fixes. Produces a re-runnable, transactional, self-verifying migration file in the backend migration folder (git-ignored). Also use when asked to "write a migration", "add a column", "change a stored procedure" or "fix data in the database".
---

# SQL migration for TifoXR

Every database change is a migration file. Never hand over loose SQL to run in a query window. The rules come from the vault decision `ADR-0002 SQL Changes Are Safe Migration Files`. This skill ships in the vault repo (`skills/sql-migration/`) and is installed as part of the TifoXR plugin. Edit it there. The vault folder is `$TIFOXR_VAULT`, and it is also printed at the start of a TifoXR session.

## Where the file goes
- Folder: `migration/` at the root of the **backend repo** (`TifoXRCoreWebAPI`). If you are in the backend repo, use its git root. Otherwise use `$TIFOXR_BACKEND` if set, or ask the user for the path. Create the folder if missing. It is git-ignored in that clone through `.git/info/exclude` (setup adds that line). Do not add it to a tracked `.gitignore` and do not commit it.
- Name: `yyyyMMdd-HHmm-short-description.sql`, for example `20261014-1530-add-package-trial-flag.sql`. Use the current date and time.
- This applies even when the work started in the CMS repo or elsewhere. Migrations always go in the backend `migration` folder.
- Never edit a migration that has already been run on any environment. Write a new file instead.

## Before writing
1. Check how current the database notes are: read `05-Database/DB Current State.md` and look at its "as of" date. If they may be stale, **ask the user** whether to run `/refresh-db`. **Never run the refresh on your own**; it connects to the dev database and needs the user's permission each time. If the user declines, say clearly that you are working from notes dated <as-of date> and that they may be out of date.
2. Read the real current structure of every table you touch in `05-Database/DB <Domain>.md` (inside the vault folder). Read only the domain notes for the tables involved.
3. For a changed stored procedure, start from the **current SQL** in `05-Database/Procedures/<name>.sql`. Never rewrite a procedure from memory. Keep all existing behaviour unless the task says otherwise.
4. Find where the backend uses the objects (grep the repositories and services) so the change does not break callers.

## Mandatory rules
1. **Idempotent.** Running the file twice must change nothing and raise no error. Check before every action:
   - table: `IF OBJECT_ID(N'dbo.t', N'U') IS NULL`
   - column: `IF COL_LENGTH(N'dbo.t', N'c') IS NULL`
   - index: `IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_x' AND object_id = OBJECT_ID(N'dbo.t'))`
   - constraint or foreign key: check `sys.objects` or `sys.foreign_keys` by name
   - drops: `IF EXISTS` / `DROP ... IF EXISTS`
   - seed rows and data fixes: `IF NOT EXISTS (...)` or a `WHERE` that only matches rows still needing the change
2. **One transaction, full rollback.** `SET XACT_ABORT ON;` then `BEGIN TRY` and `BEGIN TRANSACTION`, with `BEGIN CATCH` that rolls back if `@@TRANCOUNT > 0`, prints the error and re-throws with `THROW;`. A failure must leave the database exactly as it was.
3. **Verify before commit.** After the changes and before `COMMIT`, assert the expected end state (column exists, procedure exists, row count as expected). If it is wrong, `THROW` so everything rolls back.
4. **One batch.** `BEGIN TRY` cannot span `GO`. Do not use `GO` between steps.
5. **Dependent statements use dynamic SQL.** A statement that uses an object or column created earlier in the same batch fails to compile. Wrap it in `EXEC sys.sp_executesql N'...'`. Stored procedures, views and functions must also go through `EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE ...'`, because `CREATE` must be the first statement in a batch. Double every single quote inside the string.
6. **No data loss by accident.** Dropping a table or column, or deleting rows, only if the user explicitly asked. State the data impact in the header. Adding a NOT NULL column to a table with rows: add it with a default, or add nullable, backfill, then alter.
7. **Things that cannot run in a transaction** (`CREATE`/`ALTER DATABASE`, some full-text operations): put them in a separate file and say so in its header.
8. **Large backfills** (more than about 100,000 rows): write a separate batched script and say so in the header; do not hold one huge transaction.
9. **Plain ASCII only.** No em dashes, curly quotes or arrows in comments or strings.
10. **Print progress.** `PRINT` what was created, what was skipped, and a final success line.

## Template

```sql
/* ============================================================================
   Migration : <short title>
   Date      : <yyyy-mm-dd>        Author: <name>        Work item: <Azure DevOps id>
   Target    : dev first; test and prod only when approved
   Purpose   : <why this change is needed>
   Changes   : <tables, columns, procedures touched>
   Data loss : none   (or describe)
   Re-runnable: yes. Every step checks first; a second run changes nothing.
   Rollback  : automatic. Any error rolls back the whole migration.
   Run with  : sqlcmd -S <server> -d <database> -G -U <email> -b -i <this file>
   ============================================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- 1. Table
    IF OBJECT_ID(N'dbo.example', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.example
        (
            id   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_example PRIMARY KEY,
            name NVARCHAR(100) NOT NULL
        );
        PRINT 'Created dbo.example';
    END
    ELSE PRINT 'Skipped: dbo.example already exists';

    -- 2. Column
    IF COL_LENGTH(N'dbo.example', N'is_active') IS NULL
    BEGIN
        ALTER TABLE dbo.example ADD is_active BIT NOT NULL CONSTRAINT DF_example_is_active DEFAULT (1);
        PRINT 'Added dbo.example.is_active';
    END
    ELSE PRINT 'Skipped: dbo.example.is_active already exists';

    -- 3. Statement that uses the new column: dynamic SQL, because the column is new in this batch
    EXEC sys.sp_executesql N'UPDATE dbo.example SET is_active = 1 WHERE is_active IS NULL;';

    -- 4. Stored procedure (CREATE OR ALTER must be inside dynamic SQL here)
    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE dbo.sp_Example_GetActive
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name FROM dbo.example WHERE is_active = 1;
END';
    PRINT 'Created or updated dbo.sp_Example_GetActive';

    -- Verify the end state before committing
    IF OBJECT_ID(N'dbo.example', N'U') IS NULL OR COL_LENGTH(N'dbo.example', N'is_active') IS NULL
       OR OBJECT_ID(N'dbo.sp_Example_GetActive', N'P') IS NULL
        THROW 50001, 'Verification failed: expected objects are missing.', 1;

    COMMIT TRANSACTION;
    PRINT 'Migration complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT CONCAT('Migration FAILED and was rolled back. Error ', ERROR_NUMBER(), ', line ', ERROR_LINE(), ': ', ERROR_MESSAGE());
    THROW;
END CATCH;
```

## After writing
- Re-read the file against the mandatory rules above and fix any gap. Do not present it until it passes.
- Tell the user the file path, what it changes, and the run command. Remind them to run it on **dev** first.
- Do **not** run the migration yourself unless the user asks, and never against prod. The refresh login is meant for reading.
- After the user confirms it ran on dev, **ask permission** to run `/refresh-db` (never run it unasked), then check that the reported changes match what the migration was meant to do. Flag any difference.
- Mention once that the file is git-ignored, so it is not saved in the repo and should be backed up elsewhere.
