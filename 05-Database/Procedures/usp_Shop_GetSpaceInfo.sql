-- ============================================================
-- usp_Shop_GetSpaceInfo
-- Returns platform_type_id and entity_id from the space row.
-- Used when auto-creating the default shop during item creation.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Shop_GetSpaceInfo]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) platform_type_id, entity_id
    FROM space
    WHERE id = @SpaceId AND is_deleted = 0;
END
