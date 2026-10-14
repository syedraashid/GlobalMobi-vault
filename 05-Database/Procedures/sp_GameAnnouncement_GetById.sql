CREATE   PROCEDURE [dbo].[sp_GameAnnouncement_GetById]
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id AS Id, space_id AS SpaceId, game_id AS GameId, name AS Name, announcement_type AS AnnouncementType,
           start_date AS StartDate, end_date AS EndDate, top_count AS TopCount,
           announcement_date AS AnnouncementDate, status AS Status,
           created_by AS CreatedBy, created_time AS CreatedTime, modified_by AS ModifiedBy, modified_time AS ModifiedTime
    FROM dbo.game_announcement
    WHERE id = @Id AND is_deleted = 0;
END
