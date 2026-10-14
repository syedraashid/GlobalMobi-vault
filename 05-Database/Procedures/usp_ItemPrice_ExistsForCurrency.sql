-- ============================================================
-- usp_ItemPrice_ExistsForCurrency
-- Returns 1 row if a base price exists for item + currency.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ItemPrice_ExistsForCurrency]
    @ItemId     INT,
    @CurrencyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM item_prices
    WHERE item_id = @ItemId AND currency_id = @CurrencyId;
END
