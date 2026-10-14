-- ============================================================
-- Booth Insert Media Stored Procedure
-- Author  : Syed Raashid
-- Date    : 06/11/2026
-- Run     : Execute once against the target database.
--           CREATE OR ALTER is idempotent — safe to re-run.
--
-- Atomically adds one media item to an existing booth.
-- One transaction covers: INSERT media + media_localization
-- + i18n (text/desc) + booth_media link.
--
-- Parameters:
--   @SpaceId        INT              — owning space
--   @BoothId        INT              — target booth (must exist)
--   @ModifiedBy     NVARCHAR(255)    — audit user
--   @CreatedBy      NVARCHAR(255)    — audit user
--   @MediaTypeId    INT              — media type
--   @TextKey        UNIQUEIDENTIFIER — i18n key for text  (NULL if none)
--   @DescriptionKey UNIQUEIDENTIFIER — i18n key for desc  (NULL if none)
--   @LinkLocs       NVARCHAR(MAX)    — JSON [{locale_id, media_link}] or NULL
--   @TextLocs       NVARCHAR(MAX)    — JSON [{locale_id, value}]      or NULL
--   @DescLocs       NVARCHAR(MAX)    — JSON [{locale_id, value}]      or NULL
--
-- Returns:
--   SELECT media_id BIGINT  (1 row)  — success
--   0 rows                           — booth not found in this space
--
-- Localizations are filtered to supported locales via INNER JOIN
-- supported_languages, so the caller does not need a prior
-- sp_SupportedLanguages_Get call.
-- ============================================================

CREATE   PROCEDURE [dbo].[sp_Booth_InsertMedia]
    @SpaceId        INT,
    @BoothId        INT,
    @ModifiedBy     NVARCHAR(255),
    @CreatedBy      NVARCHAR(255),
    @MediaTypeId    INT,
    @TextKey        UNIQUEIDENTIFIER = NULL,
    @DescriptionKey UNIQUEIDENTIFIER = NULL,
    @LinkLocs       NVARCHAR(MAX)    = NULL,
    @TextLocs       NVARCHAR(MAX)    = NULL,
    @DescLocs       NVARCHAR(MAX)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validate booth exists in this space (excluding soft-deleted booths)
        IF NOT EXISTS (SELECT 1 FROM booth WHERE id = @BoothId AND space_id = @SpaceId AND is_deleted = 0)
        BEGIN
            COMMIT TRANSACTION;
            RETURN; -- 0 rows returned = not found signal to C#
        END;

        -- 2. Insert media
        DECLARE @MediaId BIGINT;

        INSERT INTO media (space_id, media_type_id, text_key, description_key, modified_by, modified_time, created_by)
        VALUES (@SpaceId, @MediaTypeId, @TextKey, @DescriptionKey, @ModifiedBy, SYSUTCDATETIME(), @CreatedBy);

        SET @MediaId = SCOPE_IDENTITY();

        -- 3. link_locs — filtered to supported locales
        IF @LinkLocs IS NOT NULL
        BEGIN
            INSERT INTO media_localization (media_id, locale_id, media_link, modified_by, modified_time, created_by)
            SELECT @MediaId, j.locale_id, j.media_link, @ModifiedBy, SYSUTCDATETIME(), @CreatedBy
            FROM   OPENJSON(@LinkLocs) WITH (
                       locale_id  NVARCHAR(20)  '$.locale_id',
                       media_link NVARCHAR(MAX) '$.media_link'
                   ) j
            INNER JOIN supported_languages sl
                ON  sl.locale_id = j.locale_id
               AND (sl.space_id  = @SpaceId OR sl.space_id IS NULL);
        END;

        -- 4. text_locs — filtered to supported locales
        IF @TextLocs IS NOT NULL AND @TextKey IS NOT NULL
        BEGIN
            INSERT INTO i18n ([key], locale_id, [value], space_id, modified_by, modified_time, created_by)
            SELECT @TextKey, j.locale_id, j.[value], @SpaceId, @ModifiedBy, SYSUTCDATETIME(), @CreatedBy
            FROM   OPENJSON(@TextLocs) WITH (
                       locale_id NVARCHAR(20)  '$.locale_id',
                       [value]   NVARCHAR(MAX) '$.value'
                   ) j
            INNER JOIN supported_languages sl
                ON  sl.locale_id = j.locale_id
               AND (sl.space_id  = @SpaceId OR sl.space_id IS NULL);
        END;

        -- 5. desc_locs — filtered to supported locales
        IF @DescLocs IS NOT NULL AND @DescriptionKey IS NOT NULL
        BEGIN
            INSERT INTO i18n ([key], locale_id, [value], space_id, modified_by, modified_time, created_by)
            SELECT @DescriptionKey, j.locale_id, j.[value], @SpaceId, @ModifiedBy, SYSUTCDATETIME(), @CreatedBy
            FROM   OPENJSON(@DescLocs) WITH (
                       locale_id NVARCHAR(20)  '$.locale_id',
                       [value]   NVARCHAR(MAX) '$.value'
                   ) j
            INNER JOIN supported_languages sl
                ON  sl.locale_id = j.locale_id
               AND (sl.space_id  = @SpaceId OR sl.space_id IS NULL);
        END;

        -- 6. booth_media link (idempotent upsert)
        DELETE FROM booth_media WHERE booth_id = @BoothId AND media_id = @MediaId;
        INSERT INTO booth_media (booth_id, media_id, modified_by, modified_time, created_by)
        VALUES (@BoothId, @MediaId, @ModifiedBy, SYSUTCDATETIME(), @CreatedBy);

        COMMIT TRANSACTION;
        SELECT @MediaId AS media_id;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
