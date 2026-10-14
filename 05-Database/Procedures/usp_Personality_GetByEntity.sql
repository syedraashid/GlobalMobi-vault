CREATE   PROCEDURE [dbo].[usp_Personality_GetByEntity]
    @EntityId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.id, p.full_name,
           pm.media_link AS photo_link
    FROM personality p
    OUTER APPLY (
        SELECT TOP (1) media_link
        FROM media_localization
        WHERE media_id = p.media_id
        ORDER BY locale_id
    ) pm
    WHERE p.is_deleted = 0 AND p.entity_id = @EntityId
    ORDER BY p.full_name;
END
