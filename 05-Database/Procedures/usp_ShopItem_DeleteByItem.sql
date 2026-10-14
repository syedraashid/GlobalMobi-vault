-- ============================================================
-- usp_ShopItem_DeleteByItem
-- Hard-deletes all shop_items rows for a given shop + item
-- (all currencies). Used in the full item removal path.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_DeleteByItem]
    @ShopId INT,
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM shop_items
    WHERE shop_id = @ShopId AND item_id = @ItemId;
END
