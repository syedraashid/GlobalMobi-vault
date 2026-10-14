-- ============================================================
-- usp_Item_GetSnapshot
-- Returns id + key columns needed before an update.
-- @SpaceId is optional: when NULL the space filter is skipped
-- (ShopItems module calls this without a spaceId).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Item_GetSnapshot]
    @ItemId  INT,
    @SpaceId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        id,
        space_id        AS SpaceId,
        name_key        AS NameKey,
        description_key AS DescriptionKey
    FROM item
    WHERE id = @ItemId
      AND (@SpaceId IS NULL OR (space_id = @SpaceId AND is_deleted = 0));
END
