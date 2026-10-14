CREATE   PROCEDURE [dbo].[sp_ProcessMetricEventBatch]
    -- Join/Exit activity types (3 types × 2 phases = 6 params)
    @SpaceJoins         NVARCHAR(MAX) = NULL,
    @SpaceExits         NVARCHAR(MAX) = NULL,
    @EventActivityJoins NVARCHAR(MAX) = NULL,
    @EventActivityExits NVARCHAR(MAX) = NULL,
    @BoothJoins         NVARCHAR(MAX) = NULL,
    @BoothExits         NVARCHAR(MAX) = NULL,
    -- Insert-only types (5 params)
    @PortalAccesses     NVARCHAR(MAX) = NULL,
    @TeleportActivities NVARCHAR(MAX) = NULL,
    @StreamingUsers     NVARCHAR(MAX) = NULL,
    @StreamingSummaries NVARCHAR(MAX) = NULL,
    @EventShares        NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Results written AFTER each TRY/CATCH, never inside a savepoint scope,
    -- so these rows are never rolled back by a savepoint rollback.
    DECLARE @Results TABLE (
        Section NVARCHAR(100)  NOT NULL,
        Status  NVARCHAR(10)   NOT NULL,   -- 'OK' | 'ERROR'
        Error   NVARCHAR(500)  NULL
    );

    -- Reused per section — set inside CATCH, read after TRY/CATCH ends.
    DECLARE @Status NVARCHAR(10);
    DECLARE @Err    NVARCHAR(500);

    -- ONE outer transaction — only one COMMIT fires, at the very bottom.
    BEGIN TRANSACTION;

    ------------------------------------------------------------------------
    -- SECTION 1 : UserSpaceActivity — Joins
    -- Idempotent: WHERE NOT EXISTS on session_id (same as old InsertJoinAsync)
    -- Unchanged: one session_id = exactly one space visit by design, so
    -- this simpler keying is correct here (unlike Booth).
    ------------------------------------------------------------------------
    IF @SpaceJoins IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_SpaceJoins;
        BEGIN TRY
            INSERT INTO user_space_activity_mtx
                (id, space_id, user_id, session_id, join_time, session_duration)
            SELECT NEWID(), j.SpaceId, j.UserId, j.SessionId, j.JoinTime, 0
            FROM OPENJSON(@SpaceJoins) WITH (
                UserId    NVARCHAR(128) '$.UserId',
                SpaceId   INT           '$.SpaceId',
                SessionId NVARCHAR(36)  '$.SessionId',
                JoinTime  DATETIME2     '$.JoinTime'
            ) AS j
            WHERE NOT EXISTS (
                SELECT 1 FROM user_space_activity_mtx x
                WHERE x.session_id = j.SessionId
            );
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_SpaceJoins;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('SpaceJoins', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 2 : UserSpaceActivity — Exits  ***UPDATED***
    -- Set-based UPDATE via INNER JOIN on OPENJSON (same semantics as old UpdateExitAsync)
    -- Hardened: "AND mtx.left_datetime IS NULL" stops a later exit from ever
    -- overwriting an already-closed row (defensive — normal case is still
    -- just one row per session either way).
    -- Now also matches SpaceId when the client sends it: newer Unity clients
    -- include SpaceId on the Exit event; older ones don't. When present, it
    -- must match exactly; when absent (older client), falls back to the
    -- session_id + user_id + left_datetime IS NULL match alone, so nothing
    -- breaks mid-rollout.
    ------------------------------------------------------------------------
    IF @SpaceExits IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_SpaceExits;
        BEGIN TRY
            UPDATE mtx
            SET exit_code        = j.ExitCode,
                session_duration = j.SessionDuration,
                left_datetime    = j.LeftDatetime,
                modified_time    = SYSUTCDATETIME()
            FROM user_space_activity_mtx mtx
            INNER JOIN OPENJSON(@SpaceExits) WITH (
                UserId          NVARCHAR(128) '$.UserId',
                SessionId       NVARCHAR(36)  '$.SessionId',
                SpaceId         INT           '$.SpaceId',
                ExitCode        INT           '$.ExitCode',
                SessionDuration INT           '$.SessionDuration',
                LeftDatetime    DATETIME2     '$.LeftDatetime'
            ) AS j ON mtx.session_id = j.SessionId
                   AND mtx.user_id    = j.UserId
                   AND mtx.left_datetime IS NULL
                   AND (j.SpaceId IS NULL OR mtx.space_id = j.SpaceId);
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_SpaceExits;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('SpaceExits', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 3 : UserEventActivity — Joins
    -- Idempotent: WHERE NOT EXISTS on (event_id, user_id, join_datetime)
    -- Unchanged — this is the reference pattern Section 5 below now follows.
    ------------------------------------------------------------------------
    IF @EventActivityJoins IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_EventActivityJoins;
        BEGIN TRY
            INSERT INTO user_event_activity_mtx
                (id, event_id, user_id, join_datetime)
            SELECT NEWID(), j.EventId, j.UserId, j.JoinDatetime
            FROM OPENJSON(@EventActivityJoins) WITH (
                UserId       NVARCHAR(128) '$.UserId',
                EventId      INT           '$.EventId',
                JoinDatetime DATETIME2     '$.JoinDatetime'
            ) AS j
            WHERE NOT EXISTS (
                SELECT 1 FROM user_event_activity_mtx x
                WHERE x.event_id      = j.EventId
                  AND x.user_id       = j.UserId
                  AND x.join_datetime = j.JoinDatetime
            );
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_EventActivityJoins;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('EventActivityJoins', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 4 : UserEventActivity — Exits
    -- Matches open row (exit_datetime IS NULL) per (event_id, user_id)
    -- Unchanged — this is the reference pattern Section 6 below now follows,
    -- adapted since BoothExits has no BoothId to key on.
    ------------------------------------------------------------------------
    IF @EventActivityExits IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_EventActivityExits;
        BEGIN TRY
            UPDATE mtx
            SET exit_reason_id = j.ExitReasonId,
                exit_datetime  = j.ExitDatetime,
                duration       = j.Duration,
                modified_time  = SYSUTCDATETIME()
            FROM user_event_activity_mtx mtx
            INNER JOIN OPENJSON(@EventActivityExits) WITH (
                UserId       NVARCHAR(128) '$.UserId',
                EventId      INT           '$.EventId',
                ExitReasonId INT           '$.ExitReasonId',
                ExitDatetime DATETIME2     '$.ExitDatetime',
                Duration     INT           '$.Duration'
            ) AS j ON mtx.event_id = j.EventId
                   AND mtx.user_id  = j.UserId
                   AND mtx.exit_datetime IS NULL;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_EventActivityExits;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('EventActivityExits', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 5 : UserBoothActivity — Joins  ***FIXED***
    -- Was: WHERE NOT EXISTS on session_id alone — blocked every booth visit
    -- in a session after the first one.
    -- Now: idempotent on the full visit identity (session_id, booth_id,
    -- entry_datetime) — still protects against a genuinely re-delivered
    -- join message, while correctly allowing a session to walk through
    -- multiple different booths.
    ------------------------------------------------------------------------
    IF @BoothJoins IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_BoothJoins;
        BEGIN TRY
            INSERT INTO user_booth_activity_mtx
                (booth_id, user_id, exit_code_id, booth_name_key,
                 session_id, entry_datetime, session_duration)
            SELECT j.BoothId, j.UserId, NULL, j.BoothNameKey,
                   j.SessionId, j.EntryDatetime, NULL
            FROM OPENJSON(@BoothJoins) WITH (
                UserId        NVARCHAR(128) '$.UserId',
                BoothId       INT           '$.BoothId',
                BoothNameKey  NVARCHAR(256) '$.BoothNameKey',
                SessionId     NVARCHAR(36)  '$.SessionId',
                EntryDatetime DATETIME2     '$.EntryDatetime'
            ) AS j
            WHERE NOT EXISTS (
                SELECT 1 FROM user_booth_activity_mtx x
                WHERE x.session_id     = j.SessionId
                  AND x.booth_id       = j.BoothId
                  AND x.entry_datetime = j.EntryDatetime
            );
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_BoothJoins;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('BoothJoins', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 6 : UserBoothActivity — Exits  ***UPDATED***
    -- Was: UPDATE matched on session_id + user_id alone — every exit event
    -- for a session re-updated the same one row, regardless of which booth
    -- it actually belonged to.
    --
    -- Now: two passes, because Unity clients are rolling out BoothId on the
    -- Exit event gradually — both old and new client versions must keep
    -- working correctly at the same time.
    --   Pass A — exits that DO carry BoothId (new client): direct, exact
    --     match on (session_id, user_id, booth_id, exit_datetime IS NULL).
    --     No ambiguity possible — same robustness as EventActivityExits.
    --   Pass B — exits that DON'T carry BoothId (old client, still rolling
    --     out): falls back to pairing the Nth-earliest such exit (by
    --     ExitDatetime) to the Nth-oldest still-open row (by entry_datetime)
    --     for that session. Pass A runs first and closes whatever it can
    --     exactly, so Pass B's ranking only ever sees rows Pass A left open.
    --     Correct as long as booth visits never overlap (the client already
    --     assumes this), same caveat as before for the legacy path only —
    --     once all clients send BoothId, Pass B never has anything to do.
    ------------------------------------------------------------------------
    IF @BoothExits IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_BoothExits;
        BEGIN TRY
            -- Pass A: exact match wherever the client sent BoothId.
            UPDATE mtx
            SET exit_code_id     = j.ExitCode,
                session_duration = j.SessionDuration,
                exit_datetime    = j.ExitDatetime,
                modified_time    = SYSUTCDATETIME()
            FROM user_booth_activity_mtx mtx
            INNER JOIN OPENJSON(@BoothExits) WITH (
                UserId          NVARCHAR(128) '$.UserId',
                SessionId       NVARCHAR(36)  '$.SessionId',
                BoothId         INT           '$.BoothId',
                ExitCode        INT           '$.ExitCode',
                SessionDuration INT           '$.SessionDuration',
                ExitDatetime    DATETIME2     '$.ExitDatetime'
            ) AS j
                ON mtx.session_id    = j.SessionId
               AND mtx.user_id       = j.UserId
               AND mtx.booth_id      = j.BoothId
               AND mtx.exit_datetime IS NULL
            WHERE j.BoothId IS NOT NULL;

            -- Pass B: legacy fallback for exits with no BoothId — pairs
            -- against whatever Pass A above left still open.
            ;WITH OpenRows AS (
                SELECT
                    mtx.id,
                    mtx.session_id,
                    mtx.user_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY mtx.session_id, mtx.user_id
                        ORDER BY mtx.entry_datetime ASC
                    ) AS rn
                FROM user_booth_activity_mtx mtx
                WHERE mtx.exit_datetime IS NULL
            ),
            IncomingLegacyExits AS (
                SELECT
                    j.UserId, j.SessionId, j.ExitCode, j.SessionDuration, j.ExitDatetime,
                    ROW_NUMBER() OVER (
                        PARTITION BY j.SessionId, j.UserId
                        ORDER BY j.ExitDatetime ASC
                    ) AS rn
                FROM OPENJSON(@BoothExits) WITH (
                    UserId          NVARCHAR(128) '$.UserId',
                    SessionId       NVARCHAR(36)  '$.SessionId',
                    BoothId         INT           '$.BoothId',
                    ExitCode        INT           '$.ExitCode',
                    SessionDuration INT           '$.SessionDuration',
                    ExitDatetime    DATETIME2     '$.ExitDatetime'
                ) AS j
                WHERE j.BoothId IS NULL
            )
            UPDATE mtx
            SET exit_code_id     = e.ExitCode,
                session_duration = e.SessionDuration,
                exit_datetime    = e.ExitDatetime,
                modified_time    = SYSUTCDATETIME()
            FROM user_booth_activity_mtx mtx
            INNER JOIN OpenRows o
                ON o.id = mtx.id
            INNER JOIN IncomingLegacyExits e
                ON e.SessionId = o.session_id
               AND e.UserId    = o.user_id
               AND e.rn        = o.rn;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_BoothExits;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('BoothExits', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 7 : PortalAccess (insert-only, NEWID() per row)
    -- Unchanged.
    ------------------------------------------------------------------------
    IF @PortalAccesses IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_PortalAccesses;
        BEGIN TRY
            INSERT INTO portal_access_mtx
                (id, user_id, space_id, portal_id, session_id, portal_type_id,
                 media_id, portal_link, media_link, thumbnail_link, access_time)
            SELECT NEWID(), j.UserId, j.SpaceId, j.PortalId, j.SessionId,
                   j.PortalTypeId, j.MediaId, j.PortalLink, j.MediaLink,
                   j.ThumbnailLink, j.AccessTime
            FROM OPENJSON(@PortalAccesses) WITH (
                UserId        NVARCHAR(128)  '$.UserId',
                SpaceId       INT            '$.SpaceId',
                PortalId      INT            '$.PortalId',
                SessionId     NVARCHAR(36)   '$.SessionId',
                PortalTypeId  INT            '$.PortalTypeId',
                MediaId       BIGINT         '$.MediaId',
                PortalLink    NVARCHAR(2048) '$.PortalLink',
                MediaLink     NVARCHAR(2048) '$.MediaLink',
                ThumbnailLink NVARCHAR(2048) '$.ThumbnailLink',
                AccessTime    DATETIME2      '$.AccessTime'
            ) AS j;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_PortalAccesses;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('PortalAccesses', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 8 : TeleportTableActivity (insert-only)
    -- Unchanged.
    ------------------------------------------------------------------------
    IF @TeleportActivities IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_TeleportActivities;
        BEGIN TRY
            INSERT INTO teleport_table_activity_mtx
                (user_id, table_id, button_id)
            SELECT j.UserId, j.TableId, j.ButtonId
            FROM OPENJSON(@TeleportActivities) WITH (
                UserId   NVARCHAR(128) '$.UserId',
                TableId  INT           '$.TableId',
                ButtonId INT           '$.ButtonId'
            ) AS j;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_TeleportActivities;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('TeleportActivities', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 9 : TifoXr3DStreamingUser (insert-only, NEWID() per row)
    -- Unchanged.
    ------------------------------------------------------------------------
    IF @StreamingUsers IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_StreamingUsers;
        BEGIN TRY
            INSERT INTO tifoxr_3d_streaming_user_mtx
                (id, user_id, user_activity_id, streaming_id,
                 os, device_type, avg_bitrate, avg_fps)
            SELECT NEWID(), j.UserId, j.UserActivityId, j.StreamingId,
                   j.Os, j.DeviceType, j.AvgBitrate, j.AvgFps
            FROM OPENJSON(@StreamingUsers) WITH (
                UserId         NVARCHAR(128) '$.UserId',
                UserActivityId NVARCHAR(36)  '$.UserActivityId',
                StreamingId    NVARCHAR(36)  '$.StreamingId',
                Os             NVARCHAR(64)  '$.Os',
                DeviceType     NVARCHAR(64)  '$.DeviceType',
                AvgBitrate     INT           '$.AvgBitrate',
                AvgFps         DECIMAL(8,2)  '$.AvgFps'
            ) AS j;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_StreamingUsers;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('StreamingUsers', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 10 : TifoXr3DStreamingSessionSummary (insert-only)
    -- Unchanged.
    ------------------------------------------------------------------------
    IF @StreamingSummaries IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_StreamingSummaries;
        BEGIN TRY
            INSERT INTO tifoxr_3d_streaming_session_summary_mtx
                (streaming_id, snapshot_time, total_viewers,
                 average_bitrate, average_fps)
            SELECT j.StreamingId, j.SnapshotTime, j.TotalViewers,
                   j.AverageBitrate, j.AvgFps
            FROM OPENJSON(@StreamingSummaries) WITH (
                StreamingId    NVARCHAR(36)  '$.StreamingId',
                SnapshotTime   DATETIME2     '$.SnapshotTime',
                TotalViewers   INT           '$.TotalViewers',
                AverageBitrate INT           '$.AverageBitrate',
                AvgFps         DECIMAL(8,2)  '$.AverageFps'
            ) AS j;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_StreamingSummaries;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('StreamingSummaries', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- SECTION 11 : EventShares (insert-only)
    -- Unchanged.
    ------------------------------------------------------------------------
    IF @EventShares IS NOT NULL
    BEGIN
        SET @Status = 'OK'; SET @Err = NULL;
        SAVE TRANSACTION sp_EventShares;
        BEGIN TRY
            INSERT INTO event_shares_mtx
                (user_id, event_id, share_channel, share_url)
            SELECT j.UserId, j.EventId, j.ShareChannel, j.ShareUrl
            FROM OPENJSON(@EventShares) WITH (
                UserId       NVARCHAR(128)  '$.UserId',
                EventId      INT            '$.EventId',
                ShareChannel NVARCHAR(128)  '$.ShareChannel',
                ShareUrl     NVARCHAR(2048) '$.ShareUrl'
            ) AS j;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION sp_EventShares;
            SET @Status = 'ERROR'; SET @Err = LEFT(ERROR_MESSAGE(), 500);
        END CATCH
        INSERT INTO @Results VALUES ('EventShares', @Status, @Err);
    END

    ------------------------------------------------------------------------
    -- ONE COMMIT — all surviving sections written to DB together
    ------------------------------------------------------------------------
    COMMIT;

    -- Return section results to MetricBatchRepository for logging.
    -- Only sections that received a non-NULL param appear in this table.
    SELECT Section, Status, Error FROM @Results;
END
