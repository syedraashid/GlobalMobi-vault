CREATE   PROCEDURE [dbo].[usp_ItemPrice_GetCurrencyImpact]
    @SpaceId INT,
    @OldCurrencyId INT
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

    SELECT
        SUM(CASE WHEN cnt.PriceRowCount = 1 THEN 1 ELSE 0 END) AS EligibleItemCount,
        SUM(CASE WHEN cnt.PriceRowCount > 1 THEN 1 ELSE 0 END) AS SkippedItemCount
    FROM (
        SELECT c.ItemId,
               (SELECT COUNT(*) FROM item_prices ip2
                WHERE ip2.item_id = c.ItemId AND ip2.is_deleted = 0) AS PriceRowCount
        FROM @Candidates c
    ) cnt;
END
