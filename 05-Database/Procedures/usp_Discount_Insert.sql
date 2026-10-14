-- ============================================================
-- usp_Discount_Insert
-- Inserts one discount row and returns the new identity id.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Discount_Insert]
    @SpaceId        INT,
    @DiscountTypeId INT,
    @NameKey        NVARCHAR(450),
    @RatePct        DECIMAL(5,2)  = NULL,
    @Amount         BIGINT        = NULL,
    @StartAt        DATE          = NULL,
    @EndAt          DATE          = NULL,
    @Metadata       NVARCHAR(MAX) = NULL,
    @CreatedBy      NVARCHAR(255),
    @ModifiedBy     NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO discounts (
        space_id, discount_type_id, name_key, rate_pct, amount, start_at, end_at, metadata,
        is_deleted, created_time, created_by, modified_time, modified_by
    )
    VALUES (
        @SpaceId, @DiscountTypeId, @NameKey, @RatePct, @Amount, @StartAt, @EndAt, @Metadata,
        0, SYSUTCDATETIME(), @CreatedBy, SYSUTCDATETIME(), @ModifiedBy
    );
    SELECT SCOPE_IDENTITY() AS id;
END
