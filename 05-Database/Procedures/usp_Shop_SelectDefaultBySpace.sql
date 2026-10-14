-- ============================================================
-- usp_Shop_SelectDefaultBySpace
-- Returns the lowest-id non-deleted shop for the space.
-- Returns 0 rows when none exists — C# creates one automatically.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Shop_SelectDefaultBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) id
    FROM shop
    WHERE space_id = @SpaceId AND is_deleted = 0
    ORDER BY id;
END
