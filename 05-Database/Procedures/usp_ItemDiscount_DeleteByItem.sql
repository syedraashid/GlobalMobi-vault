-- ============================================================
-- usp_ItemDiscount_DeleteByItem
-- Hard-deletes all item_discounts records for an item.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ItemDiscount_DeleteByItem]
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM item_discounts WHERE item_id = @ItemId;
END
