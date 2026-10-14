-- ============================================================
-- Booth Media GET Stored Procedure
-- Author : Syed Raashid
-- Date   : 05/25/2026
-- Run    : Execute once against the target database.
--          CREATE OR ALTER is idempotent — safe to re-run.
--
-- Called by LoadBoothMediaAsync to fetch media and i18n
-- for one or more booths in a single round-trip.
--
-- Parameters:
--   @SpaceId  INT            — owning space
--   @BoothIds NVARCHAR(MAX)  — JSON integer array e.g. [1, 2, 3]
--
-- Returns 2 result sets:
--   RS1 — Booth media rows with link localizations (media_localization)
--   RS2 — text_key and description_key i18n values for those media
--
-- Why a temp table for media IDs?
--   RS2 joins against the media IDs surfaced by RS1. Computing them
--   again inside RS2 with a repeated OPENJSON + JOIN is possible but
--   duplicates the booth_media scan. Storing the distinct media IDs
--   once in #MediaIds keeps RS2 simple and avoids re-reading the
--   same rows. Both result sets also run against the same locked
--   snapshot (same transaction), so RS2 will never see a media row
--   that RS1 did not.
--
-- Why WITH (NOLOCK)?
--   LoadBoothMediaAsync is called on every booth GET request.
--   Shared locks on booth_media / media / media_localization / i18n
--   would block concurrent booth CREATE / UPDATE writes. A slightly
--   stale media view is acceptable; blocking writes is not.
--
-- Why SET XACT_ABORT ON?
--   If RS2 fails after RS1 has already been returned to the reader,
--   SQL Server must not leave the connection in a dirty state.
--   XACT_ABORT ON guarantees an immediate full abort on any runtime
--   error, regardless of error severity.
--
-- Why BEGIN TRANSACTION inside BEGIN TRY (not before)?
--   If BEGIN TRANSACTION is placed before BEGIN TRY and it fails,
--   the error is not caught. CATCH then tries to ROLLBACK a
--   transaction that was never opened, raising error 3903 that
--   masks the original error. Placing it inside TRY ensures any
--   failure — including failing to open the transaction — is caught
--   and re-raised correctly.
--
-- Why IF @@TRANCOUNT > 0 before ROLLBACK in CATCH?
--   SET XACT_ABORT ON can automatically roll back the transaction
--   before control reaches CATCH, leaving @@TRANCOUNT at 0. A
--   blind ROLLBACK at that point raises error 3903. The guard
--   makes ROLLBACK safe in all code paths.
--
-- Why temp table cleanup in CATCH?
--   DROP TABLE #MediaIds runs at end of TRY on success. If RS2
--   fails, CATCH fires and that DROP never executes. A temp table
--   left on a pooled connection causes "object already exists" on
--   the next call that reuses that connection. The IF OBJECT_ID
--   guard in CATCH closes this gap.
-- ============================================================

CREATE   PROCEDURE [dbo].[sp_Booth_GetMedia]
    @SpaceId  INT,
    @BoothIds NVARCHAR(MAX)   -- JSON integer array: [1, 2, 3]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Collect distinct media IDs from the incoming booth set.
        -- Used by RS2 to avoid re-scanning booth_media a second time.
        CREATE TABLE #MediaIds (media_id BIGINT NOT NULL PRIMARY KEY);

        INSERT INTO #MediaIds (media_id)
        SELECT DISTINCT bm.media_id
        FROM   booth_media bm WITH (NOLOCK)
        JOIN   (SELECT CAST([value] AS INT) AS id FROM OPENJSON(@BoothIds)) ids
                   ON ids.id = bm.booth_id
        INNER JOIN media m WITH (NOLOCK)
                   ON  m.id         = bm.media_id
                   AND m.space_id   = @SpaceId
                   AND m.is_deleted = 0
        WHERE  bm.is_deleted = 0;

        -- ── RS1: Booth media + link localizations ─────────────────
        SELECT
            bm.booth_id,
            bm.media_id,
            m.media_type_id,
            m.text_key,
            m.description_key,
            ml.locale_id,
            ml.media_link,
            bm.created_time AS created_at,
            ca.id                  AS approval_id,
            ca.[status]            AS approval_status,
            ca.action_type         AS approval_action_type,
            ca.[current_snapshot]  AS current_snapshot,
            ca.[proposed_snapshot] AS proposed_snapshot,
            bm.[status]            AS content_status
        FROM   booth_media bm WITH (NOLOCK)
        JOIN   (SELECT CAST([value] AS INT) AS id FROM OPENJSON(@BoothIds)) ids
                   ON ids.id = bm.booth_id
        INNER JOIN media m WITH (NOLOCK)
                   ON  m.id         = bm.media_id
                   AND m.space_id   = @SpaceId
                   AND m.is_deleted = 0
        LEFT JOIN  media_localization ml WITH (NOLOCK)
                   ON  ml.media_id   = m.id
                   AND ml.is_deleted = 0
        OUTER APPLY (
            SELECT TOP 1 ca2.id, ca2.[status], ca2.action_type,
                         ca2.[current_snapshot], ca2.[proposed_snapshot]
            FROM   dbo.content_approval ca2
            WHERE  ca2.content_type = 'booth_media'
              AND  ca2.content_id   = bm.media_id
              AND  ca2.[status]    != 'withdrawn'
            ORDER BY ca2.id DESC
        ) ca
        WHERE  bm.is_deleted = 0
        ORDER BY bm.booth_id, bm.media_id, ml.locale_id;

        -- ── RS2: text_key / description_key i18n for those media ──
        SELECT m.id AS media_id, 'text' AS key_type, i.locale_id, i.[value]
        FROM   media m WITH (NOLOCK)
        INNER JOIN i18n i WITH (NOLOCK)
                   ON  i.[key]      = m.text_key
                   AND i.space_id   = @SpaceId
                   AND i.is_deleted = 0
        WHERE  m.id IN (SELECT media_id FROM #MediaIds)
          AND  m.text_key IS NOT NULL

        UNION ALL

        SELECT m.id AS media_id, 'desc' AS key_type, i.locale_id, i.[value]
        FROM   media m WITH (NOLOCK)
        INNER JOIN i18n i WITH (NOLOCK)
                   ON  i.[key]      = m.description_key
                   AND i.space_id   = @SpaceId
                   AND i.is_deleted = 0
        WHERE  m.id IN (SELECT media_id FROM #MediaIds)
          AND  m.description_key IS NOT NULL

        ORDER BY media_id, key_type, locale_id;

        DROP TABLE #MediaIds;
        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#MediaIds') IS NOT NULL
            DROP TABLE #MediaIds;
        THROW;
    END CATCH
END;
