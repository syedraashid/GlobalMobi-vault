-- ============================================================
-- usp_ItemDiscount_Insert
-- Links a discount to an item via item_discounts.
-- region_id = NULL = global (no regional override).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ItemDiscount_Insert]
    @ItemId     INT,
    @DiscountId INT,
    @CreatedBy  NVARCHAR(255),
    @ModifiedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO item_discounts (item_id, discount_id, region_id, is_deleted, created_time, created_by, modified_time, modified_by)
    VALUES (@ItemId, @DiscountId, NULL, 0, SYSUTCDATETIME(), @CreatedBy, SYSUTCDATETIME(), @ModifiedBy);
END
