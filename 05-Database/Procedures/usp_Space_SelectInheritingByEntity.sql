CREATE   PROCEDURE [dbo].[usp_Space_SelectInheritingByEntity]
    @EntityId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id AS SpaceId
    FROM [space]
    WHERE entity_id = @EntityId
      AND currency_id IS NULL;
END
