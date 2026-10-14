-- ============================================================
-- usp_ShopItem_SelectEnvelope
-- Returns shop_item summary for UPDATE response.
-- PascalCase column aliases to match C# MapShopItemsListRow reader.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_SelectEnvelope]
    @SpaceId    INT,
    @ShopId     INT,
    @ItemId     INT,
    @CurrencyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
      i.id                              AS Id,
      i.item_type_id                    AS Item_Type_Id,
      i.name_key                        AS Name_Key,
      i.description_key                 AS Description_Key,
      i.is_available                    AS Is_Available,
      COALESCE(si.amount, ip.base_cost) AS Price_Minor_Units,
      si.stock_quantity                 AS Stock_Quantity,
      si.currency_id                    AS Currency_Id,
      d.name_key                        AS Discount_Name_Key,
      d.discount_type_id                AS Discount_Type,
      d.rate_pct                        AS Discount_Rate_Pct,
      d.amount                          AS Discount_Amount_Minor_Units,
      d.start_at                        AS Discount_Start_At,
      d.end_at                          AS Discount_End_At
    FROM shop_items si
    JOIN item i               ON i.id = si.item_id
    JOIN shop s               ON s.id = si.shop_id AND s.space_id = @SpaceId
    LEFT JOIN item_prices ip  ON ip.item_id = i.id
                              AND ip.currency_id = si.currency_id
    LEFT JOIN (
        SELECT *
        FROM (
            SELECT
              idsc.item_id,
              ISNULL(idsc.region_id, 0) AS region_key,
              d2.id                      AS discount_id,
              d2.name_key,
              d2.discount_type_id,
              d2.rate_pct,
              d2.amount,
              d2.start_at,
              d2.end_at,
              ROW_NUMBER() OVER (
                PARTITION BY idsc.item_id, ISNULL(idsc.region_id, 0)
                ORDER BY d2.end_at DESC, d2.id DESC
              ) rn
            FROM item_discounts idsc
            JOIN discounts d2 ON d2.id = idsc.discount_id
            WHERE (d2.start_at IS NULL OR CAST(SYSUTCDATETIME() AS date) >= d2.start_at)
              AND (d2.end_at   IS NULL OR CAST(SYSUTCDATETIME() AS date) <= d2.end_at)
        ) ranked
        WHERE ranked.rn = 1
    ) d
      ON d.item_id   = i.id
     AND d.region_key = 0
    WHERE si.shop_id     = @ShopId
      AND si.item_id     = @ItemId
      AND si.currency_id = @CurrencyId;
END
