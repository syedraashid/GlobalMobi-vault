CREATE   PROCEDURE [dbo].[sp_GameAnnouncement_ListActiveForPublish]
    @SpaceId INT,
    @Today   DATE,
    @GameId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ga.id               AS AnnouncementId,
        ga.name             AS Name,
        ga.game_id          AS GameId,
        g.game_code         AS GameCode,
        ga.announcement_type AS AnnouncementType,
        ga.start_date       AS StartDate,
        ga.end_date         AS EndDate,
        ga.announcement_date AS AnnouncementDate,
        ga.top_count        AS TopCount
    FROM dbo.game_announcement ga
    JOIN dbo.game g ON g.id = ga.game_id
    WHERE ga.space_id   = @SpaceId
      AND ga.is_deleted  = 0
      AND g.is_deleted   = 0
      AND g.is_active    = 1
      AND ga.start_date <= @Today
      AND ga.end_date   >= @Today
      AND (@GameId IS NULL OR ga.game_id = @GameId)
    ORDER BY ga.end_date, ga.start_date;

    SELECT
        pp.announcement_id AS AnnouncementId,
        pp.item_id         AS ItemId,
        it.[type]          AS ItemTypeName
    FROM dbo.game_announcement_prize_pack pp
    JOIN dbo.game_announcement ga ON ga.id = pp.announcement_id
    JOIN dbo.game g                ON g.id  = ga.game_id
    JOIN dbo.item i                 ON i.id  = pp.item_id AND i.is_deleted = 0
    JOIN dbo.item_type it           ON it.id = i.item_type_id
    WHERE pp.is_deleted  = 0
      AND ga.space_id    = @SpaceId
      AND ga.is_deleted  = 0
      AND g.is_deleted   = 0
      AND g.is_active    = 1
      AND ga.start_date <= @Today
      AND ga.end_date   >= @Today
      AND (@GameId IS NULL OR ga.game_id = @GameId)
    ORDER BY pp.announcement_id, pp.item_id;
END
