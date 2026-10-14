-- ============================================================
-- usp_Discount_SoftExpire
-- Sets end_at to today if currently NULL or in the future.
-- Used as the "soft delete" path for discounts.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Discount_SoftExpire]
    @DiscountId INT,
    @SpaceId    INT,
    @ModifiedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE discounts
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE id = @DiscountId AND space_id = @SpaceId AND is_deleted = 0;

    UPDATE item_discounts
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE discount_id = @DiscountId AND is_deleted = 0;

    UPDATE i18n
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE [key]      = (SELECT CAST(name_key AS UNIQUEIDENTIFIER)
                        FROM discounts
                        WHERE id = @DiscountId AND space_id = @SpaceId)
      AND space_id   = @SpaceId
      AND is_deleted = 0;
END
