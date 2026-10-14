CREATE   PROCEDURE [dbo].[sp_GetSpacesWithGameAnnouncements]
    @Today DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT ga.space_id
    FROM dbo.game_announcement ga
    JOIN dbo.game g ON g.id = ga.game_id
    WHERE ga.is_deleted = 0
      AND g.is_deleted  = 0
      AND g.is_active   = 1
      AND ga.end_date  >= @Today;
END
