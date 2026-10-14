-- ============================================================
-- usp_ShopItem_ExistsMapping
-- Returns 1 row if a non-deleted shop_items mapping exists.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_ExistsMapping]
    @SpaceId    INT,
    @ShopId     INT,
    @ItemId     INT,
    @CurrencyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM shop_items si
    JOIN shop s ON s.id = si.shop_id AND s.space_id = @SpaceId
    JOIN item i ON i.id = si.item_id AND i.space_id = @SpaceId AND i.is_deleted = 0
    WHERE si.shop_id     = @ShopId
      AND si.item_id     = @ItemId
      AND si.currency_id = @CurrencyId
      AND si.is_deleted  = 0;
END
