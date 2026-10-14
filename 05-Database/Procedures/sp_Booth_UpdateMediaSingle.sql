-- ============================================================
-- sp_Booth_UpdateMediaSingle
-- Updates one booth_media item in a single transaction:
--   1. Verifies the media belongs to @SpaceId (returns no rows
--      = false if not found).
--   2. Resolves text_key / description_key from DB when caller
--      did not supply them.
--   3. Replaces media_type_id.
--   4. Replaces all link localizations (if @LinkLocs supplied).
--   5. Replaces text i18n        (if @TextLocs supplied).
--   6. Replaces description i18n (if @DescLocs supplied).
--   7. Sets booth_media.status   (if @ForceStatus supplied).
--
-- @LinkLocs / @TextLocs / @DescLocs: JSON [{locale_id, ...}]
--   NULL = skip that block entirely (leave unchanged)
--   '[]' = delete all rows for that key
-- ============================================================
CREATE   PROCEDURE [dbo].[sp_Booth_UpdateMediaSingle]
    @SpaceId     INT,
    @MediaId     BIGINT,
    @MediaTypeId INT,
    @LinkLocs    NVARCHAR(MAX) = NULL,
    @TextKey     NVARCHAR(64)  = NULL,
    @TextLocs    NVARCHAR(MAX) = NULL,
    @DescKey     NVARCHAR(64)  = NULL,
    @DescLocs    NVARCHAR(MAX) = NULL,
    @ForceStatus VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Verify ownership
        IF NOT EXISTS (
            SELECT 1
            FROM   [dbo].[booth_media] bm
            JOIN   [dbo].[booth]       b  ON b.id = bm.booth_id AND b.space_id = @SpaceId
            WHERE  bm.media_id = @MediaId AND bm.is_deleted = 0
        )
        BEGIN
            COMMIT TRANSACTION;
            RETURN;   -- 0 rows returned → caller gets false
        END;

        -- 2. Resolve keys from DB when caller omitted them
        DECLARE @ResolvedTextKey NVARCHAR(64) = @TextKey;
        DECLARE @ResolvedDescKey NVARCHAR(64) = @DescKey;

        IF @ResolvedTextKey IS NULL OR @ResolvedDescKey IS NULL
        BEGIN
            SELECT
                @ResolvedTextKey = COALESCE(@ResolvedTextKey, CONVERT(NVARCHAR(64), m.text_key)),
                @ResolvedDescKey = COALESCE(@ResolvedDescKey, CONVERT(NVARCHAR(64), m.description_key))
            FROM [dbo].[media] m
            WHERE m.id = @MediaId;
        END;

        -- 3. Update media_type_id
        UPDATE [dbo].[media] SET media_type_id = @MediaTypeId WHERE id = @MediaId;

        -- 4. Replace link localizations
        IF @LinkLocs IS NOT NULL
        BEGIN
            DELETE FROM [dbo].[media_localization] WHERE media_id = @MediaId;

            INSERT INTO [dbo].[media_localization] (media_id, locale_id, media_link)
            SELECT @MediaId, j.locale_id, j.media_link
            FROM   OPENJSON(@LinkLocs) WITH (
                locale_id  NVARCHAR(20)  '$.locale_id',
                media_link NVARCHAR(MAX) '$.media_link'
            ) j
            WHERE  j.locale_id IS NOT NULL AND j.media_link IS NOT NULL;
        END;

        -- 5. Replace text i18n
        IF @TextLocs IS NOT NULL AND @ResolvedTextKey IS NOT NULL
        BEGIN
            DELETE FROM [dbo].[i18n]
            WHERE  [key] = @ResolvedTextKey AND space_id = @SpaceId;

            INSERT INTO [dbo].[i18n] ([key], locale_id, [value], space_id)
            SELECT @ResolvedTextKey, j.locale_id, j.[value], @SpaceId
            FROM   OPENJSON(@TextLocs) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            WHERE  j.[value] IS NOT NULL AND j.[value] <> '';
        END;

        -- 6. Replace description i18n
        IF @DescLocs IS NOT NULL AND @ResolvedDescKey IS NOT NULL
        BEGIN
            DELETE FROM [dbo].[i18n]
            WHERE  [key] = @ResolvedDescKey AND space_id = @SpaceId;

            INSERT INTO [dbo].[i18n] ([key], locale_id, [value], space_id)
            SELECT @ResolvedDescKey, j.locale_id, j.[value], @SpaceId
            FROM   OPENJSON(@DescLocs) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            WHERE  j.[value] IS NOT NULL AND j.[value] <> '';
        END;

        -- 7. Apply status override
        IF @ForceStatus IS NOT NULL
            UPDATE [dbo].[booth_media] SET [status] = @ForceStatus WHERE media_id = @MediaId;

        COMMIT TRANSACTION;
        SELECT 1 AS found;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
