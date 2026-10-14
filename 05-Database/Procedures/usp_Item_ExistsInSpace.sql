-- ============================================================
-- usp_Item_ExistsInSpace
-- Guard check before PUT / DELETE — returns 1 row if found, 0 if not.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Item_ExistsInSpace]
    @ItemId  INT,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM item
    WHERE id = @ItemId AND space_id = @SpaceId AND is_deleted = 0;
END
