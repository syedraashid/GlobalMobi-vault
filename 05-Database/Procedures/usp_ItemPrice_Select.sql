-- ============================================================
-- usp_ItemPrice_Select
-- Returns the server price for an item in a specific shop and currency.
-- Uses shop_items.amount as the override price if set; falls back to
-- item_prices.base_cost. Returns 0 rows if the item is not active in
-- this shop/currency — C# rejects the order with 422 in that case.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ItemPrice_Select]
    @ItemRefId  INT,
    @ShopId     INT,
    @CurrencyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        COALESCE(si.amount, ip.base_cost) AS server_price
    FROM shop_items si
    JOIN item_prices ip ON ip.item_id    = si.item_id
                       AND ip.currency_id = si.currency_id
    WHERE si.shop_id     = @ShopId
      AND si.item_id     = @ItemRefId
      AND si.currency_id = @CurrencyId
      AND si.is_deleted  = 0;
END
