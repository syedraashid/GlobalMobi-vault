-- ── 8. sp_CustomBoothItem_Update ────────────────────────────

CREATE   PROCEDURE [dbo].[sp_CustomBoothItem_Update]
    @SpaceId               INT,
    @Id                    INT,
    @BoothId               INT,
    @CustomBoothItemTypeId INT = NULL,
    @CorrespondingMediaId  BIGINT,
    @StartDatetime         DATETIME2 = NULL,
    @HasStartDatetime      BIT = 0,
    @EndDatetime           DATETIME2 = NULL,
    @HasEndDatetime        BIT = 0,
    @ModifiedBy            VARCHAR(36),
    @ForceStatus           VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM custom_booth_item WHERE id = @Id AND booth_id = @BoothId AND is_deleted = 0)
    BEGIN
        SELECT 0 AS success;
        RETURN;
    END

    UPDATE custom_booth_item
    SET custom_booth_item_type_id = ISNULL(@CustomBoothItemTypeId, custom_booth_item_type_id),
        corresponding_media_id    = @CorrespondingMediaId,
        start_datetime            = CASE WHEN @HasStartDatetime = 1 THEN @StartDatetime ELSE start_datetime END,
        end_datetime              = CASE WHEN @HasEndDatetime   = 1 THEN @EndDatetime   ELSE end_datetime   END,
        [status]                  = ISNULL(@ForceStatus, CASE WHEN [status] = 'approved' THEN 'pending' ELSE [status] END),
        modified_by               = @ModifiedBy,
        modified_time             = SYSUTCDATETIME()
    WHERE id = @Id AND booth_id = @BoothId;

    SELECT 1 AS success;
END
