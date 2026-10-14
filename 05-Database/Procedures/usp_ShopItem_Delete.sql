-- ============================================================
-- usp_ShopItem_Delete
-- Hard-deletes a single shop_items mapping (space-scoped guard).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_Delete]
    @SpaceId    INT,
    @ShopId     INT,
    @ItemId     INT,
    @CurrencyId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE si
    FROM shop_items si
    JOIN shop s ON s.id = si.shop_id AND s.space_id = @SpaceId
    JOIN item i ON i.id = si.item_id AND i.space_id = @SpaceId
    WHERE si.shop_id     = @ShopId
      AND si.item_id     = @ItemId
      AND si.currency_id = @CurrencyId;
END
