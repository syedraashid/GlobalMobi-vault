-- ── 4b. Per-player match history + best score, for the CMS "Details" drill-down.
-- Scoped to the same @FromDate/@ToDate window as the table it was opened from (both
-- NULL => all-time), so the chart/stat tiles agree with whatever filter produced the
-- row the user clicked. Reads only user_game_session — never the scoreboard rollup —
-- since only individual match rows can answer "highest single score" or "last N matches".
CREATE   PROCEDURE [dbo].[sp_Scoreboard_GetPlayerHistory]
    @SpaceId  INT,
    @GameId   INT,
    @UserId   UNIQUEIDENTIFIER,
    @FromDate DATE = NULL,
    @ToDate   DATE = NULL,
    @Limit    INT = 5
AS
BEGIN
    SET NOCOUNT ON;
    IF @Limit < 1 OR @Limit > 50 SET @Limit = 5;

    DECLARE @RangeStart DATETIME2 = CASE WHEN @FromDate IS NULL THEN NULL ELSE CAST(@FromDate AS DATETIME2) END;
    DECLARE @RangeEndExclusive DATETIME2 = CASE WHEN @FromDate IS NULL AND @ToDate IS NULL THEN NULL
                                                 ELSE DATEADD(DAY, 1, CAST(ISNULL(@ToDate, @FromDate) AS DATETIME2)) END;

    ;WITH scoped AS (
        -- CAST to BIGINT here too: score_value is int, and the C# reader reads both Score
        -- and HighestScore as Int64 unconditionally (same class of bug already fixed once
        -- in sp_Scoreboard_GetByDateRange's date-range branch — MAX(int)/a bare int column
        -- both come back as int, not bigint, and throw an Int32->Int64 cast exception the
        -- instant a real row exists).
        SELECT CAST(s.score_value AS BIGINT) AS score_value, s.start_time
        FROM dbo.user_game_session s
        JOIN dbo.user_session_management usm ON usm.id = s.user_session_id
        WHERE s.game_id = @GameId
          AND usm.space_id = @SpaceId
          AND s.user_id = @UserId
          AND s.is_deleted = 0
          AND (@RangeStart IS NULL OR s.start_time >= @RangeStart)
          AND (@RangeEndExclusive IS NULL OR s.start_time < @RangeEndExclusive)
    ),
    recent AS (
        SELECT TOP (@Limit) score_value, start_time
        FROM scoped
        ORDER BY start_time DESC
    )
    SELECT r.score_value AS Score, r.start_time AS PlayedAt,
           (SELECT MAX(score_value) FROM scoped) AS HighestScore
    FROM recent r
    ORDER BY r.start_time ASC;  -- chronological, so a chart reads left-to-right oldest-to-newest
END;
