-- ── 6. Repointed: only reads total_score, no column-drop impact otherwise ──
CREATE   PROCEDURE [dbo].[sp_Leaderboard_GetUserGameStats]
    @SpaceId INT,
    @UserId  UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT g.id                      AS GameId,
           g.name_key                AS NameKey,
           ISNULL(sb.total_score, 0) AS TotalScore
    FROM dbo.game g
    LEFT JOIN dbo.user_game_scoreboard sb
        ON sb.game_id = g.id AND sb.user_id = @UserId AND sb.space_id = @SpaceId AND sb.is_deleted = 0
    WHERE g.is_deleted = 0
    ORDER BY g.sort_order;
END;
