-- ============================================================
-- usp_Currency_Exists
-- Returns 1 row if the currency exists and is not deleted.
-- Returns 0 rows if not found â€” C# checks reader.HasRows.
-- Replaces: ItemSql.ExistsCurrency, ShopItemsSql.ExistsCurrency
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Currency_Exists]
    @CurrencyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1 AS found
    FROM currency
    WHERE id = @CurrencyId AND is_deleted = 0;
END
