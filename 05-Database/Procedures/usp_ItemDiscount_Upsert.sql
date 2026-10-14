-- ============================================================
-- usp_ItemDiscount_Upsert
-- MERGE-based upsert for item_discounts. Updates timestamps if
-- the mapping already exists, inserts otherwise.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ItemDiscount_Upsert]
    @ItemId     INT,
    @RegionId   INT           = NULL,
    @DiscountId INT,
    @ModifiedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    MERGE item_discounts AS target
    USING (SELECT @ItemId AS item_id, @RegionId AS region_id, @DiscountId AS discount_id) AS source
        ON target.item_id     = source.item_id
       AND target.discount_id = source.discount_id
       AND (target.region_id = source.region_id OR (target.region_id IS NULL AND source.region_id IS NULL))
    WHEN MATCHED THEN
        UPDATE SET
            modified_time = SYSUTCDATETIME(),
            modified_by   = @ModifiedBy
    WHEN NOT MATCHED THEN
        INSERT (item_id, discount_id, region_id, is_deleted, created_time, created_by, modified_time, modified_by)
        VALUES (@ItemId, @DiscountId, @RegionId, 0, SYSUTCDATETIME(), @ModifiedBy, SYSUTCDATETIME(), @ModifiedBy);
END
