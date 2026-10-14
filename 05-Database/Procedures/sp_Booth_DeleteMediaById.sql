-- ============================================================
-- sp_Booth_DeleteMediaById
-- Atomically deletes a booth media item and all its dependent
-- rows (media_localization, booth_media, media, i18n).
-- Verifies space ownership before touching any data.
-- Returns SELECT 1 AS found on success; 0 rows if not found.
-- ============================================================
CREATE   PROCEDURE [dbo].[sp_Booth_DeleteMediaById]
    @SpaceId INT,
    @MediaId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @BoothId INT;
        DECLARE @TextKey NVARCHAR(64);
        DECLARE @DescKey NVARCHAR(64);

        -- Verify ownership and collect i18n keys for cleanup
        SELECT
            @BoothId = bm.booth_id,
            @TextKey = CONVERT(NVARCHAR(64), m.text_key),
            @DescKey = CONVERT(NVARCHAR(64), m.description_key)
        FROM   [dbo].[booth_media] bm
        JOIN   [dbo].[booth]       b ON bm.booth_id = b.id AND b.space_id = @SpaceId
        LEFT JOIN [dbo].[media]    m ON m.id = bm.media_id
        WHERE  bm.media_id = @MediaId;

        IF @BoothId IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;

        DELETE FROM [dbo].[media_localization] WHERE media_id = @MediaId;
        DELETE FROM [dbo].[booth_media]        WHERE booth_id = @BoothId AND media_id = @MediaId;
        DELETE FROM [dbo].[media]              WHERE id = @MediaId;

        IF @TextKey IS NOT NULL
            DELETE FROM [dbo].[i18n] WHERE [key] = @TextKey AND space_id = @SpaceId;
        IF @DescKey IS NOT NULL
            DELETE FROM [dbo].[i18n] WHERE [key] = @DescKey AND space_id = @SpaceId;

        COMMIT TRANSACTION;
        SELECT 1 AS found;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
