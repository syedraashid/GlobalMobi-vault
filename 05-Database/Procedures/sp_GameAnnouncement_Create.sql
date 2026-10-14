CREATE   PROCEDURE [dbo].[sp_GameAnnouncement_Create]
    @SpaceId             INT,
    @GameId              INT,
    @Name                VARCHAR(200),
    @AnnouncementType    VARCHAR(10),
    @StartDate           DATE,
    @EndDate             DATE,
    @TopCount            INT = 10,
    @AnnouncementDate    DATE = NULL,
    @CreatedBy           VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.game_announcement
        (space_id, game_id, name, announcement_type, start_date, end_date, top_count, announcement_date, status, created_by, modified_by)
    VALUES
        (@SpaceId, @GameId, @Name, @AnnouncementType, @StartDate, @EndDate, @TopCount, @AnnouncementDate, 'draft', @CreatedBy, @CreatedBy);

    SELECT id AS Id, space_id AS SpaceId, game_id AS GameId, name AS Name, announcement_type AS AnnouncementType,
           start_date AS StartDate, end_date AS EndDate, top_count AS TopCount,
           announcement_date AS AnnouncementDate, status AS Status,
           created_by AS CreatedBy, created_time AS CreatedTime, modified_by AS ModifiedBy, modified_time AS ModifiedTime
    FROM dbo.game_announcement
    WHERE id = SCOPE_IDENTITY();
END
