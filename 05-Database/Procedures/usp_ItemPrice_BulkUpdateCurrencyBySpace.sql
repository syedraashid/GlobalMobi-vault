-- Only touches items with EXACTLY ONE non-deleted price row (skips multi-
-- currency items). @Multiplier NULL => relabel only (currency_id changes,
-- amounts unchanged). Also keeps shop_items.currency_id/amount in sync —
-- usp_ItemPrice_Select (used by order creation) requires an exact match
-- between item_prices.currency_id and shop_items.currency_id as a join key,
-- not just a label, so this must stay in lockstep with item_prices or order
-- creation starts failing with "Item X is not listed in shop Y for currency Z".
CREATE   PROCEDURE [dbo].[usp_ItemPrice_BulkUpdateCurrencyBySpace]
    @SpaceId INT,
    @OldCurrencyId INT,
    @NewCurrencyId INT,
    @Multiplier DECIMAL(28,10) = NULL,
    @ModifiedBy VARCHAR(200) = 'system:currency-cascade'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Candidates TABLE (ItemId INT PRIMARY KEY);
    INSERT INTO @Candidates (ItemId)
    SELECT DISTINCT ip.item_id
    FROM item_prices ip
    INNER JOIN [item] i ON i.id = ip.item_id
    WHERE i.space_id = @SpaceId
      AND i.is_deleted = 0
      AND ip.is_deleted = 0
      AND ip.currency_id = @OldCurrencyId;

    DECLARE @Skipped TABLE (ItemId INT PRIMARY KEY);
    INSERT INTO @Skipped (ItemId)
    SELECT c.ItemId FROM @Candidates c
    WHERE (SELECT COUNT(*) FROM item_prices ip2
           WHERE ip2.item_id = c.ItemId AND ip2.is_deleted = 0) > 1;

    UPDATE ip
    SET ip.currency_id   = @NewCurrencyId,
        ip.base_cost     = CASE WHEN @Multiplier IS NOT NULL
                                 THEN CAST(ROUND(ip.base_cost * @Multiplier, 0) AS BIGINT)
                                 ELSE ip.base_cost END,
        ip.modified_by   = @ModifiedBy,
        ip.modified_time = SYSUTCDATETIME()
    FROM item_prices ip
    INNER JOIN @Candidates c ON c.ItemId = ip.item_id
    WHERE ip.is_deleted = 0
      AND NOT EXISTS (SELECT 1 FROM @Skipped s WHERE s.ItemId = c.ItemId);

    UPDATE si
    SET si.currency_id   = @NewCurrencyId,
        si.amount        = CASE WHEN @Multiplier IS NOT NULL AND si.amount IS NOT NULL
                                 THEN CAST(ROUND(si.amount * @Multiplier, 0) AS BIGINT)
                                 ELSE si.amount END,
        si.modified_by   = @ModifiedBy,
        si.modified_time = SYSUTCDATETIME()
    FROM shop_items si
    INNER JOIN @Candidates c ON c.ItemId = si.item_id
    WHERE si.is_deleted = 0
      AND si.currency_id = @OldCurrencyId
      AND NOT EXISTS (SELECT 1 FROM @Skipped s WHERE s.ItemId = c.ItemId);

    SELECT c.ItemId AS UpdatedItemId
    FROM @Candidates c
    WHERE NOT EXISTS (SELECT 1 FROM @Skipped s WHERE s.ItemId = c.ItemId);

    SELECT ItemId AS SkippedItemId FROM @Skipped;
END
