-- ============================================================
-- usp_ShopItem_Add
-- Inserts a shop_items mapping row.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_Add]
    @ShopId        INT,
    @ItemId        INT,
    @CurrencyId    INT,
    @Amount        BIGINT        = NULL,
    @StockQuantity INT           = NULL,
    @ModifiedBy    NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO shop_items
      (shop_id, item_id, currency_id, amount, stock_quantity, modified_time, modified_by)
    VALUES
      (@ShopId, @ItemId, @CurrencyId, @Amount, COALESCE(@StockQuantity, 0), SYSUTCDATETIME(), @ModifiedBy);
END
