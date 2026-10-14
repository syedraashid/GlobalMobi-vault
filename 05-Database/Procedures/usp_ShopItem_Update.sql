-- ============================================================
-- usp_ShopItem_Update
-- Updates amount and stock_quantity for an existing mapping.
-- NULL @Amount directly clears the override (intentional).
-- NULL @StockQuantity keeps the existing value (COALESCE).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_Update]
    @ShopId        INT,
    @ItemId        INT,
    @CurrencyId    INT,
    @Amount        BIGINT        = NULL,
    @StockQuantity INT           = NULL,
    @ModifiedBy    NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE shop_items
    SET
      amount         = @Amount,
      stock_quantity = COALESCE(@StockQuantity, stock_quantity),
      modified_time  = SYSUTCDATETIME(),
      modified_by    = @ModifiedBy
    WHERE shop_id     = @ShopId
      AND item_id     = @ItemId
      AND currency_id = @CurrencyId;
END
