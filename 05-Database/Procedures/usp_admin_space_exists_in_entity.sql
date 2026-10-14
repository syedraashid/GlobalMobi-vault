-- Returns: scalar BIT
CREATE   PROCEDURE [dbo].[usp_admin_space_exists_in_entity]
    @SpaceId  INT,
    @EntityId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(COUNT(1) AS BIT)
    FROM   [dbo].[space]
    WHERE  [id] = @SpaceId AND [entity_id] = @EntityId;
END
