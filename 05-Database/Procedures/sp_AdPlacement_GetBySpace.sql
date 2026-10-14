-- Space-scoped: returns only placement slots belonging to the given space.
CREATE   PROCEDURE [dbo].[sp_AdPlacement_GetBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, space_id, placement_key, label, is_3d
    FROM ad_placement
    WHERE space_id = @SpaceId AND is_deleted = 0
    ORDER BY placement_key;
END;
