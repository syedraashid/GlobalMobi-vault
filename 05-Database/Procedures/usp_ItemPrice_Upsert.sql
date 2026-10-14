-- ============================================================
-- usp_ItemPrice_Upsert
-- MERGE: updates base_cost if the row exists, inserts otherwise.
-- Requires UNIQUE(item_id, currency_id) on item_prices.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ItemPrice_Upsert]
    @ItemId     INT,
    @CurrencyId INT,
    @BaseCost   BIGINT,
    @ModifiedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    MERGE item_prices AS t
    USING (SELECT @ItemId AS item_id, @CurrencyId AS currency_id) AS s
    ON (t.item_id = s.item_id AND t.currency_id = s.currency_id)
    WHEN MATCHED THEN
        UPDATE SET
            t.base_cost     = @BaseCost,
            t.modified_by   = @ModifiedBy,
            t.modified_time = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (item_id, currency_id, base_cost, modified_by)
        VALUES (@ItemId, @CurrencyId, @BaseCost, @ModifiedBy);
END
