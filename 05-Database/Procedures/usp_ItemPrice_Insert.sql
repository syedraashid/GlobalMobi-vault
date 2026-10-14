-- ============================================================
-- usp_ItemPrice_Insert
-- Inserts one price row for an item in a given currency.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ItemPrice_Insert]
    @ItemId     INT,
    @CurrencyId INT,
    @BaseCost   BIGINT,
    @ModifiedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO item_prices (item_id, currency_id, base_cost, modified_by)
    VALUES (@ItemId, @CurrencyId, @BaseCost, @ModifiedBy);
END
