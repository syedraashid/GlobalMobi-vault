-- ============================================================
-- usp_ShopItem_CountBySpace
-- Returns count of active shop_items mappings for an item in a space.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_CountBySpace]
    @SpaceId INT,
    @ItemId  INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*)
    FROM shop_items si
    JOIN shop s ON s.id = si.shop_id
    WHERE s.space_id  = @SpaceId
      AND si.item_id  = @ItemId
      AND si.is_deleted = 0;
END
