-- ── 4. New admin/CMS paginated scoreboard proc ──────────────────────────────
-- @FromDate/@ToDate both NULL => all-time (fast path off the maintained rollup).
-- Otherwise aggregates user_game_session in [@FromDate, @ToDate] inclusive,
-- scoped to @SpaceId via user_session_management (session rows carry no
-- space_id of their own).
CREATE   PROCEDURE [dbo].[sp_Scoreboard_GetByDateRange]
    @SpaceId       INT,
    @GameId        INT,
    @FromDate      DATE = NULL,
    @ToDate        DATE = NULL,
    @Page          INT = 1,
    @PageSize      INT = 25,
    @SearchTerm    NVARCHAR(200) = NULL,   -- matches username OR email, either side of the string
    @SortDirection VARCHAR(4) = 'ASC'      -- 'ASC' = top-first (rank 1 first), 'DESC' = bottom-first
AS
BEGIN
    SET NOCOUNT ON;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 OR @PageSize > 200 SET @PageSize = 25;
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'ASC';
    DECLARE @Offset INT = (@Page - 1) * @PageSize;
    -- LIKE needs literal %/_/[ escaped or they're treated as wildcards inside the search term itself.
    DECLARE @SearchPattern NVARCHAR(204) = NULL;
    IF @SearchTerm IS NOT NULL AND LTRIM(RTRIM(@SearchTerm)) <> ''
        SET @SearchPattern = '%' + REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@SearchTerm)), '[', '[[]'), '%', '[%]'), '_', '[_]') + '%';

    IF @FromDate IS NULL AND @ToDate IS NULL
    BEGIN
        ;WITH ranked AS (
            SELECT sb.user_id, u.username, u.email, sb.total_score AS score,
                   sb.games_played, sb.last_played_time,
                   RANK() OVER (ORDER BY sb.total_score DESC, u.username ASC) AS rnk
            FROM dbo.user_game_scoreboard sb
            JOIN dbo.[user] u ON u.id = sb.user_id
            WHERE sb.space_id = @SpaceId AND sb.game_id = @GameId AND sb.is_deleted = 0
              -- Exclude guest/anonymous accounts (user_type_id 1 = 'anonymous' in
              -- dbo.user_type, 2 = 'registered' — these are the "Guest96359"-style rows
              -- with no email on file) from the CMS scoreboard entirely.
              AND u.user_type_id <> 1
              AND (@SearchPattern IS NULL OR u.username LIKE @SearchPattern ESCAPE '[' OR u.email LIKE @SearchPattern ESCAPE '[')
        )
        SELECT user_id AS UserId, username AS Username, email AS Email, score AS Score,
               rnk AS Rank, games_played AS GamesPlayed, last_played_time AS LastPlayedTime,
               (SELECT COUNT_BIG(*) FROM ranked) AS TotalCount
        FROM ranked
        ORDER BY CASE WHEN @SortDirection = 'ASC' THEN rnk END ASC,
                 CASE WHEN @SortDirection = 'DESC' THEN rnk END DESC
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
        RETURN;
    END;

    DECLARE @RangeStart DATETIME2 = CAST(@FromDate AS DATETIME2);
    DECLARE @RangeEndExclusive DATETIME2 = DATEADD(DAY, 1, CAST(ISNULL(@ToDate, @FromDate) AS DATETIME2));

    ;WITH agg AS (
        -- CAST to BIGINT: score_value is int, so SUM(score_value) would otherwise come
        -- back as int here while the all-time branch above returns total_score (bigint) —
        -- the two branches must agree on Score's SQL type since the C# reader reads it
        -- as Int64 unconditionally (same reasoning as the RANK()-is-always-bigint note
        -- in sp_Leaderboard_GetTopAndCurrentUser).
        SELECT s.user_id, SUM(CAST(s.score_value AS BIGINT)) AS score, COUNT(*) AS games_played, MAX(s.end_time) AS last_played_time
        FROM dbo.user_game_session s
        JOIN dbo.user_session_management usm ON usm.id = s.user_session_id
        WHERE s.game_id = @GameId
          AND usm.space_id = @SpaceId
          AND s.start_time >= @RangeStart AND s.start_time < @RangeEndExclusive
          AND s.is_deleted = 0
        GROUP BY s.user_id
    ),
    ranked AS (
        SELECT a.user_id, u.username, u.email, a.score, a.games_played, a.last_played_time,
               RANK() OVER (ORDER BY a.score DESC, u.username ASC) AS rnk
        FROM agg a
        JOIN dbo.[user] u ON u.id = a.user_id
        WHERE u.user_type_id <> 1
          AND (@SearchPattern IS NULL OR u.username LIKE @SearchPattern ESCAPE '[' OR u.email LIKE @SearchPattern ESCAPE '[')
    )
    SELECT user_id AS UserId, username AS Username, email AS Email, score AS Score,
           rnk AS Rank, games_played AS GamesPlayed, last_played_time AS LastPlayedTime,
           (SELECT COUNT_BIG(*) FROM ranked) AS TotalCount
    FROM ranked
    ORDER BY CASE WHEN @SortDirection = 'ASC' THEN rnk END ASC,
             CASE WHEN @SortDirection = 'DESC' THEN rnk END DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
