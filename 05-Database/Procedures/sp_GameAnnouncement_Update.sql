CREATE   PROCEDURE [dbo].[sp_GameAnnouncement_Update]
    @Id                  INT,
    @Name                VARCHAR(200),
    @AnnouncementType    VARCHAR(10),
    @StartDate           DATE,
    @EndDate             DATE,
    @TopCount            INT,
    @AnnouncementDate    DATE = NULL,
    @Status              VARCHAR(20),
    @ModifiedBy          VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.game_announcement
    SET name                   = @Name,
        announcement_type      = @AnnouncementType,
        start_date             = @StartDate,
        end_date               = @EndDate,
        top_count              = @TopCount,
        announcement_date      = @AnnouncementDate,
        status                 = @Status,
        modified_by            = @ModifiedBy,
        modified_time          = SYSUTCDATETIME()
    WHERE id = @Id AND is_deleted = 0;

    SELECT id AS Id, space_id AS SpaceId, game_id AS GameId, name AS Name, announcement_type AS AnnouncementType,
           start_date AS StartDate, end_date AS EndDate, top_count AS TopCount,
           announcement_date AS AnnouncementDate, status AS Status,
           created_by AS CreatedBy, created_time AS CreatedTime, modified_by AS ModifiedBy, modified_time AS ModifiedTime
    FROM dbo.game_announcement
    WHERE id = @Id AND is_deleted = 0;
END
