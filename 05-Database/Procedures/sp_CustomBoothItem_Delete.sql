-- ── 9. sp_CustomBoothItem_Delete ────────────────────────────
CREATE   PROCEDURE [dbo].[sp_CustomBoothItem_Delete]
    @SpaceId INT,
    @Id      INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CorrMediaId BIGINT, @NameKey UNIQUEIDENTIFIER, @DescKey UNIQUEIDENTIFIER;

        SELECT @CorrMediaId = ci.corresponding_media_id, @NameKey = ci.name_key, @DescKey = ci.description_key
        FROM   custom_booth_item ci
        JOIN   booth b ON b.id = ci.booth_id AND b.space_id = @SpaceId
        WHERE  ci.id = @Id;

        IF @CorrMediaId IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS success;
            RETURN;
        END

        DECLARE @LinkThumbIds TABLE (media_id BIGINT PRIMARY KEY);
        INSERT INTO @LinkThumbIds
            SELECT thumbnail_media_id FROM custom_booth_item_link
            WHERE custom_booth_item_id = @Id AND thumbnail_media_id IS NOT NULL;

        -- Links first — they FK to custom_booth_item and must go before the header row.
        DELETE FROM custom_booth_item_link WHERE custom_booth_item_id = @Id;

        DELETE FROM custom_booth_item WHERE id = @Id;

        DELETE FROM media_localization WHERE media_id IN (SELECT media_id FROM @LinkThumbIds);
        DELETE FROM media WHERE id IN (SELECT media_id FROM @LinkThumbIds);

        DELETE FROM media_localization WHERE media_id = @CorrMediaId;
        DELETE FROM media WHERE id = @CorrMediaId;
        DELETE FROM i18n WHERE [key] IN (@NameKey, @DescKey);

        COMMIT TRANSACTION;
        SELECT 1 AS success;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
