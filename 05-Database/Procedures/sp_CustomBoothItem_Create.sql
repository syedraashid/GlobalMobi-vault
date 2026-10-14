-- ── 7. sp_CustomBoothItem_Create ────────────────────────────

CREATE   PROCEDURE [dbo].[sp_CustomBoothItem_Create]
    @SpaceId               INT,
    @BoothId               INT,
    @CustomBoothItemTypeId INT,
    @CorrespondingMediaId  BIGINT,
    @NameKey               UNIQUEIDENTIFIER,
    @DescriptionKey        UNIQUEIDENTIFIER = NULL,
    @StartDatetime         DATETIME2 = NULL,
    @EndDatetime           DATETIME2 = NULL,
    @CreatedBy             VARCHAR(36),
    @ModifiedBy            VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM booth WHERE id = @BoothId AND space_id = @SpaceId)
    BEGIN
        RAISERROR('Booth not found in this space.', 16, 1);
        RETURN;
    END

    INSERT INTO custom_booth_item
        (booth_id, custom_booth_item_type_id, corresponding_media_id, name_key, description_key,
         start_datetime, end_datetime, created_by, modified_by)
    OUTPUT INSERTED.id
    VALUES
        (@BoothId, @CustomBoothItemTypeId, @CorrespondingMediaId, @NameKey, @DescriptionKey,
         @StartDatetime, @EndDatetime, @CreatedBy, @ModifiedBy);
END
