-- ============================================================
-- usp_Shop_ExistsInSpace
-- Returns 1 row if the shop belongs to the given space.
-- Returns 0 rows if not found â€” C# checks ExecuteScalar for null.
-- Replaces:
--   OrderSql.Shop_ExistsInSpace (inline SELECT in OrderRepository.Write.cs)
--   ShopItemsSql.ExistsShopInSpace
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Shop_ExistsInSpace]
    @ShopId  INT,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1 AS found
    FROM shop
    WHERE id = @ShopId AND space_id = @SpaceId;
END
