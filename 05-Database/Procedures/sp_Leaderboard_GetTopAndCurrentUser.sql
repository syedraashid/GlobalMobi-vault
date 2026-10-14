-- ── 5. REVERTED to original, plus NEW monthly: player-facing top+me. Weekly
--       AND monthly both read from their maintained rolling columns (not
--       computed on the fly) — a row's weekly_score/monthly_score only reset
--       the moment they're next written to (see the MERGE in
--       sp_GameSession_InsertAndUpdateLeaderboardBatch below) — this proc
--       corrects a stale (prior week's/month's) number at READ time by
--       checking week_start_date/month_start_date against the current
--       week/month, so a stored-but-stale value never leaks into a ranking.
CREATE   PROCEDURE [dbo].[sp_Leaderboard_GetTopAndCurrentUser]
    @SpaceId       INT,
    @GameId        INT,
    @Top           INT,
    @CurrentUserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentWeekStart DATE = DATEADD(DAY, DATEDIFF(DAY, 0, SYSUTCDATETIME()) / 7 * 7, 0);
    DECLARE @CurrentMonthStart DATE = DATEFROMPARTS(YEAR(SYSUTCDATETIME()), MONTH(SYSUTCDATETIME()), 1);

    ;WITH base AS (
        SELECT ulb.user_id, u.username, ulb.total_score,
               CASE WHEN ulb.week_start_date = @CurrentWeekStart THEN ulb.weekly_score ELSE 0 END AS effective_weekly_score,
               CASE WHEN ulb.month_start_date = @CurrentMonthStart THEN ulb.monthly_score ELSE 0 END AS effective_monthly_score
        FROM dbo.user_game_scoreboard ulb
        JOIN dbo.[user] u ON u.id = ulb.user_id
        WHERE ulb.space_id = @SpaceId AND ulb.game_id = @GameId AND ulb.is_deleted = 0
    ),
    ranked AS (
        SELECT *,
               RANK() OVER (ORDER BY total_score DESC, username ASC) AS all_time_rank,
               RANK() OVER (ORDER BY effective_weekly_score DESC, username ASC) AS weekly_rank,
               RANK() OVER (ORDER BY effective_monthly_score DESC, username ASC) AS monthly_rank
        FROM base
    )
    SELECT user_id                AS UserId,
           username                AS Username,
           total_score             AS TotalScore,
           all_time_rank           AS AllTimeRank,
           effective_weekly_score  AS WeeklyScore,
           weekly_rank             AS WeeklyRank,
           effective_monthly_score AS MonthlyScore,
           monthly_rank            AS MonthlyRank
    FROM ranked
    WHERE all_time_rank <= @Top OR weekly_rank <= @Top OR monthly_rank <= @Top OR user_id = @CurrentUserId
    ORDER BY all_time_rank;
END;
