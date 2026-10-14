-- ── 7. REVERTED to original: batch writer maintains weekly_score again ─────
CREATE   PROCEDURE [dbo].[sp_GameSession_InsertAndUpdateLeaderboardBatch]
    @Sessions           NVARCHAR(MAX),
    @MinDurationSeconds INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Rows TABLE (
        Seq            INT IDENTITY(1,1) PRIMARY KEY,
        UserId         UNIQUEIDENTIFIER,
        UserSessionId  UNIQUEIDENTIFIER,
        SpaceId        INT,
        GameId         INT,
        ScoreValue     INT,
        StartTime      DATETIME2,
        EndTime        DATETIME2,
        ReceivedAtUtc  DATETIME2
    );

    INSERT INTO @Rows (UserId, UserSessionId, SpaceId, GameId, ScoreValue, StartTime, EndTime, ReceivedAtUtc)
    SELECT s.UserId, s.UserSessionId, s.SpaceId, s.GameId, s.ScoreValue, s.StartTime, s.EndTime, s.ReceivedAtUtc
    FROM OPENJSON(@Sessions) AS arr
    CROSS APPLY OPENJSON(arr.value)
    WITH (
        UserId        UNIQUEIDENTIFIER '$.UserId',
        UserSessionId UNIQUEIDENTIFIER '$.UserSessionId',
        SpaceId       INT              '$.SpaceId',
        GameId        INT              '$.GameId',
        ScoreValue    INT              '$.ScoreValue',
        StartTime     DATETIME2        '$.StartTime',
        EndTime       DATETIME2        '$.EndTime',
        ReceivedAtUtc DATETIME2        '$.ReceivedAtUtc'
    ) AS s
    ORDER BY CAST(arr.[key] AS INT);

    DECLARE @Seq INT, @MaxSeq INT;
    DECLARE @UserId UNIQUEIDENTIFIER, @UserSessionId UNIQUEIDENTIFIER,
            @SpaceId INT, @GameId INT, @ScoreValue INT, @StartTime DATETIME2, @EndTime DATETIME2,
            @ReceivedAtUtc DATETIME2;

    SELECT @Seq = MIN(Seq), @MaxSeq = MAX(Seq) FROM @Rows;

    BEGIN TRY
        BEGIN TRANSACTION;

        WHILE @Seq IS NOT NULL AND @Seq <= @MaxSeq
        BEGIN
            SELECT @UserId = UserId, @UserSessionId = UserSessionId,
                   @SpaceId = SpaceId, @GameId = GameId, @ScoreValue = ScoreValue,
                   @StartTime = StartTime, @EndTime = EndTime, @ReceivedAtUtc = ReceivedAtUtc
            FROM @Rows WHERE Seq = @Seq;

            INSERT INTO dbo.user_game_session (user_id, user_session_id, game_id, score_value, coins_earned, start_time, end_time)
            SELECT @UserId, @UserSessionId, @GameId, @ScoreValue, 0, @StartTime, @EndTime
            FROM dbo.game g
            WHERE g.id = @GameId
              AND DATEDIFF(SECOND, @StartTime, @EndTime) >= @MinDurationSeconds
              AND (g.max_score IS NULL OR @ScoreValue <= g.max_score)
              -- Space-scoped overlap check: user_game_session itself has no space_id
              -- (only derivable via user_session_management), so the original version of
              -- this guard compared time-overlap across ALL spaces for this user+game —
              -- meaning a legitimate session in space B could be silently rejected as a
              -- "duplicate" of an overlapping session in space A. Joining usm2 and
              -- filtering to @SpaceId restricts the guard to true duplicates within the
              -- same space only.
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.user_game_session x2
                  JOIN dbo.user_session_management usm2 ON usm2.id = x2.user_session_id
                  WHERE x2.user_id = @UserId AND x2.game_id = @GameId
                    AND usm2.space_id = @SpaceId
                    AND x2.start_time < @EndTime AND @StartTime < x2.end_time
              );

            IF @@ROWCOUNT > 0
            BEGIN
                -- A row's weekly_score/weekly_games_played (and monthly_score/
                -- monthly_games_played, same shape) only reset the moment they're next
                -- written to (not proactively at the week/month boundary) — each CASE WHEN
                -- checks whether the stored week_start_date/month_start_date still matches
                -- the week/month this session landed in; if not, a new period has started,
                -- so that counter resets to just this session instead of accumulating onto
                -- the prior period's number.
                DECLARE @WeekStart DATE = DATEADD(DAY, DATEDIFF(DAY, 0, @ReceivedAtUtc) / 7 * 7, 0);
                DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@ReceivedAtUtc), MONTH(@ReceivedAtUtc), 1);

                MERGE dbo.user_game_scoreboard AS target
                USING (SELECT @UserId AS user_id, @SpaceId AS space_id, @GameId AS game_id, @ScoreValue AS score_delta, @WeekStart AS week_start, @MonthStart AS month_start) AS src
                ON target.user_id = src.user_id AND target.space_id = src.space_id AND target.game_id = src.game_id
                WHEN MATCHED THEN
                    UPDATE SET total_score = target.total_score + src.score_delta,
                               games_played = target.games_played + 1,
                               weekly_score = CASE WHEN target.week_start_date = src.week_start
                                                   THEN target.weekly_score + src.score_delta
                                                   ELSE src.score_delta END,
                               weekly_games_played = CASE WHEN target.week_start_date = src.week_start
                                                          THEN target.weekly_games_played + 1
                                                          ELSE 1 END,
                               week_start_date = src.week_start,
                               monthly_score = CASE WHEN target.month_start_date = src.month_start
                                                   THEN target.monthly_score + src.score_delta
                                                   ELSE src.score_delta END,
                               monthly_games_played = CASE WHEN target.month_start_date = src.month_start
                                                          THEN target.monthly_games_played + 1
                                                          ELSE 1 END,
                               month_start_date = src.month_start,
                               last_played_time = @EndTime,
                               modified_time = SYSUTCDATETIME()
                WHEN NOT MATCHED THEN
                    INSERT (user_id, space_id, game_id, total_score, games_played, weekly_score, weekly_games_played, week_start_date, monthly_score, monthly_games_played, month_start_date, last_played_time, modified_time, modified_by)
                    VALUES (src.user_id, src.space_id, src.game_id, src.score_delta, 1, src.score_delta, 1, src.week_start, src.score_delta, 1, src.month_start, @EndTime, SYSUTCDATETIME(), 'system');
            END;

            SELECT @Seq = MIN(Seq) FROM @Rows WHERE Seq > @Seq;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
