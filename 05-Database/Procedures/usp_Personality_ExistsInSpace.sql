CREATE   PROCEDURE [dbo].[usp_Personality_ExistsInSpace]
    @PersonalityId INT,
    @SpaceId       INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM personality p
    JOIN entity e ON p.entity_id = e.id
    WHERE p.id = @PersonalityId
      AND e.space_id  = @SpaceId
      AND p.is_deleted = 0
      AND e.is_deleted = 0;
END
