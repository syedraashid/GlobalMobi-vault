-- ============================================================
-- usp_ShopItem_GetItemKeys
-- Returns name_key and description_key for a shop mapping.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_GetItemKeys]
    @SpaceId    INT,
    @ShopId     INT,
    @ItemId     INT,
    @CurrencyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        i.name_key        AS NameKey,
        i.description_key AS DescriptionKey
    FROM shop_items si
    JOIN shop s ON s.id = si.shop_id AND s.space_id = @SpaceId
    JOIN item i ON i.id = si.item_id AND i.space_id = @SpaceId
    WHERE si.shop_id     = @ShopId
      AND si.item_id     = @ItemId
      AND si.currency_id = @CurrencyId;
END
