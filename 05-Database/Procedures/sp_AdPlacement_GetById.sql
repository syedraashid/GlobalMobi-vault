-- One live placement of a space. 0 rows = not found (missing, deleted, or another space's).
CREATE   PROCEDURE [dbo].[sp_AdPlacement_GetById]
    @SpaceId INT,
    @Id      INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id, space_id, placement_key, label, is_3d
    FROM   dbo.ad_placement
    WHERE  id = @Id AND space_id = @SpaceId AND is_deleted = 0;
END;
