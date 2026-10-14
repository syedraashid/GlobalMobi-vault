CREATE   PROCEDURE [dbo].[usp_ShopItem_UpdateStock]
    @ItemId        INT,
    @StockQuantity INT,
    @ModifiedBy    NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE shop_items
    SET stock_quantity = @StockQuantity,
        modified_time  = SYSUTCDATETIME(),
        modified_by    = @ModifiedBy
    WHERE item_id = @ItemId AND is_deleted = 0;
END
