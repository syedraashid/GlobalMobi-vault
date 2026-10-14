-- ============================================================
-- SECTION 6 — Ticket capacity / stock quantity ("Total Available Seat")

-- ============================================================

CREATE   PROCEDURE [dbo].[usp_ShopItem_InsertFromItem]
    @ShopId        INT,
    @ItemId        INT,
    @CurrencyId    INT,
    @ModifiedBy    NVARCHAR(255),
    @StockQuantity INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO shop_items (shop_id, item_id, currency_id, amount, stock_quantity,
                            modified_time, modified_by)
    VALUES (@ShopId, @ItemId, @CurrencyId, NULL, @StockQuantity, SYSUTCDATETIME(), @ModifiedBy);
END
