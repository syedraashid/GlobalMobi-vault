-- ============================================================
-- Migration: BoothTeleportSync
-- Script:    01_sp_Booth_Update_TeleportSync.sql
-- Purpose:   ALTER sp_Booth_Update to auto-sync the linked
--            teleport button (same map_spot) when a booth edit
--            is approved. Syncs map_spot_id + localized names
--            atomically inside the existing transaction.
--
-- No schema changes. No C# changes. SP only.
-- Safe to re-run (ALTER PROCEDURE is idempotent).
-- ============================================================

CREATE PROCEDURE [dbo].[sp_Booth_Update]
    @SpaceId     INT,
    @BoothId     INT,
    @MapSpotId   INT           = NULL,
    @ModifiedBy  NVARCHAR(255) = NULL,
    @CreatedBy   NVARCHAR(255) = NULL,
    @I18nName    NVARCHAR(MAX) = NULL,
    @MediaItems  NVARCHAR(MAX) = NULL,
    @ForceStatus VARCHAR(20)   = NULL,
    @IconKey     VARCHAR(50)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Lock and read booth (capture old map_spot_id before any update)
        DECLARE @NameKey      UNIQUEIDENTIFIER;
        DECLARE @OldMapSpotId INT;

        SELECT @NameKey      = name_key,
               @OldMapSpotId = map_spot_id
        FROM   booth WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE  id       = @BoothId
          AND  space_id = @SpaceId;

        IF @NameKey IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;

        -- 2. Validate map_spot (skip when unassigning)
        IF @MapSpotId > 0
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM map_spot WHERE id = @MapSpotId)
                THROW 50002, 'MapSpot not found.', 1;
        END;

        -- 3. Update booth row
        UPDATE booth
        SET    map_spot_id   = @MapSpotId,
               modified_by   = ISNULL(@ModifiedBy, modified_by),
               modified_time = SYSUTCDATETIME(),
               [status]      = ISNULL(@ForceStatus, [status]),
               icon_key      = ISNULL(@IconKey, icon_key)
        WHERE  id       = @BoothId
          AND  space_id = @SpaceId;

        -- 4. i18n name - 3-step soft-delete
        IF @I18nName IS NOT NULL
        BEGIN
            -- Step a: soft-delete all active translations for booth name key
            UPDATE i18n
            SET    is_deleted = 1
            WHERE  [key]      = @NameKey
              AND  space_id   = @SpaceId
              AND  is_deleted = 0;

            -- Step b-1: re-activate rows whose locale is in the payload
            UPDATE i18n
            SET    is_deleted = 0,
                   [value]    = j.[value]
            FROM   i18n
            INNER JOIN OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j ON i18n.locale_id = j.locale_id
            WHERE  i18n.[key]    = @NameKey
              AND  i18n.space_id = @SpaceId;

            -- Step b-2: insert locales that have never had a physical row
            INSERT INTO i18n ([key], locale_id, [value], space_id, created_by)
            SELECT @NameKey, j.locale_id, j.[value], @SpaceId, @CreatedBy
            FROM   OPENJSON(@I18nName) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            LEFT JOIN i18n x
                ON  x.[key]     = @NameKey
                AND x.locale_id = j.locale_id
                AND x.space_id  = @SpaceId
            WHERE x.locale_id IS NULL;
        END;

        -- 5. Media items
        IF @MediaItems IS NOT NULL
        BEGIN
            CREATE TABLE #IncomingMedia (
                row_num         INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
                media_id        BIGINT        NOT NULL,
                media_type_id   INT           NOT NULL,
                text_key        NVARCHAR(MAX) NULL,
                description_key NVARCHAR(MAX) NULL,
                link_locs       NVARCHAR(MAX) NULL,
                text_locs       NVARCHAR(MAX) NULL,
                desc_locs       NVARCHAR(MAX) NULL
            );

            INSERT INTO #IncomingMedia
                (media_id, media_type_id, text_key, description_key,
                 link_locs, text_locs, desc_locs)
            SELECT
                CAST(JSON_VALUE(value, '$.id')            AS BIGINT),
                CAST(JSON_VALUE(value, '$.media_type_id') AS INT),
                     JSON_VALUE(value, '$.text_key'),
                     JSON_VALUE(value, '$.description_key'),
                     JSON_QUERY(value, '$.link_locs'),
                     JSON_QUERY(value, '$.text_locs'),
                     JSON_QUERY(value, '$.desc_locs')
            FROM OPENJSON(@MediaItems);

            DECLARE @MRow         INT = 1;
            DECLARE @MMaxRow      INT = (SELECT COUNT(1) FROM #IncomingMedia);
            DECLARE @MMediaId     BIGINT;
            DECLARE @MMediaType   INT;
            DECLARE @MTextKey     NVARCHAR(MAX);
            DECLARE @MDescKey     NVARCHAR(MAX);
            DECLARE @MLinkLocs    NVARCHAR(MAX);
            DECLARE @MTextLocs    NVARCHAR(MAX);
            DECLARE @MDescLocs    NVARCHAR(MAX);
            DECLARE @MTextKeyGuid UNIQUEIDENTIFIER;
            DECLARE @MDescKeyGuid UNIQUEIDENTIFIER;

            WHILE @MRow <= @MMaxRow
            BEGIN
                SET @MTextKeyGuid = NULL;
                SET @MDescKeyGuid = NULL;

                SELECT
                    @MMediaId   = media_id,
                    @MMediaType = media_type_id,
                    @MTextKey   = text_key,
                    @MDescKey   = description_key,
                    @MLinkLocs  = link_locs,
                    @MTextLocs  = text_locs,
                    @MDescLocs  = desc_locs
                FROM #IncomingMedia
                WHERE row_num = @MRow;

                UPDATE media
                SET    media_type_id   = @MMediaType,
                       text_key        = TRY_CAST(@MTextKey AS UNIQUEIDENTIFIER),
                       description_key = TRY_CAST(@MDescKey AS UNIQUEIDENTIFIER),
                       modified_by     = ISNULL(@ModifiedBy, modified_by),
                       modified_time   = SYSUTCDATETIME()
                WHERE  id       = @MMediaId
                  AND  space_id = @SpaceId;

                IF @MLinkLocs IS NOT NULL
                BEGIN
                    UPDATE media_localization
                    SET    is_deleted = 1
                    WHERE  media_id   = @MMediaId
                      AND  is_deleted = 0;

                    UPDATE media_localization
                    SET    is_deleted = 0,
                           media_link = j.media_link
                    FROM   media_localization
                    INNER JOIN OPENJSON(@MLinkLocs) WITH (
                        locale_id  NVARCHAR(20)  '$.locale_id',
                        media_link NVARCHAR(MAX) '$.media_link'
                    ) j ON media_localization.locale_id = j.locale_id
                    WHERE  media_localization.media_id = @MMediaId;

                    INSERT INTO media_localization (media_id, locale_id, media_link, created_by)
                    SELECT @MMediaId, j.locale_id, j.media_link, @CreatedBy
                    FROM   OPENJSON(@MLinkLocs) WITH (
                        locale_id  NVARCHAR(20)  '$.locale_id',
                        media_link NVARCHAR(MAX) '$.media_link'
                    ) j
                    LEFT JOIN media_localization x
                        ON  x.media_id  = @MMediaId
                        AND x.locale_id = j.locale_id
                    WHERE x.locale_id IS NULL;
                END;

                IF @MTextLocs IS NOT NULL
                BEGIN
                    SET @MTextKeyGuid = TRY_CAST(@MTextKey AS UNIQUEIDENTIFIER);
                    IF @MTextKeyGuid IS NOT NULL
                    BEGIN
                        UPDATE i18n SET is_deleted = 1
                        WHERE  [key] = @MTextKeyGuid AND space_id = @SpaceId AND is_deleted = 0;

                        UPDATE i18n
                        SET    is_deleted = 0, [value] = j.[value]
                        FROM   i18n
                        INNER JOIN OPENJSON(@MTextLocs) WITH (
                            locale_id NVARCHAR(20)  '$.locale_id',
                            [value]   NVARCHAR(MAX) '$.value'
                        ) j ON i18n.locale_id = j.locale_id
                        WHERE  i18n.[key] = @MTextKeyGuid AND i18n.space_id = @SpaceId;

                        INSERT INTO i18n ([key], locale_id, [value], space_id, created_by)
                        SELECT @MTextKeyGuid, j.locale_id, j.[value], @SpaceId, @CreatedBy
                        FROM   OPENJSON(@MTextLocs) WITH (
                            locale_id NVARCHAR(20)  '$.locale_id',
                            [value]   NVARCHAR(MAX) '$.value'
                        ) j
                        LEFT JOIN i18n x
                            ON  x.[key]     = @MTextKeyGuid
                            AND x.locale_id = j.locale_id
                            AND x.space_id  = @SpaceId
                        WHERE x.locale_id IS NULL;
                    END;
                END;

                IF @MDescLocs IS NOT NULL
                BEGIN
                    SET @MDescKeyGuid = TRY_CAST(@MDescKey AS UNIQUEIDENTIFIER);
                    IF @MDescKeyGuid IS NOT NULL
                    BEGIN
                        UPDATE i18n SET is_deleted = 1
                        WHERE  [key] = @MDescKeyGuid AND space_id = @SpaceId AND is_deleted = 0;

                        UPDATE i18n
                        SET    is_deleted = 0, [value] = j.[value]
                        FROM   i18n
                        INNER JOIN OPENJSON(@MDescLocs) WITH (
                            locale_id NVARCHAR(20)  '$.locale_id',
                            [value]   NVARCHAR(MAX) '$.value'
                        ) j ON i18n.locale_id = j.locale_id
                        WHERE  i18n.[key] = @MDescKeyGuid AND i18n.space_id = @SpaceId;

                        INSERT INTO i18n ([key], locale_id, [value], space_id, created_by)
                        SELECT @MDescKeyGuid, j.locale_id, j.[value], @SpaceId, @CreatedBy
                        FROM   OPENJSON(@MDescLocs) WITH (
                            locale_id NVARCHAR(20)  '$.locale_id',
                            [value]   NVARCHAR(MAX) '$.value'
                        ) j
                        LEFT JOIN i18n x
                            ON  x.[key]     = @MDescKeyGuid
                            AND x.locale_id = j.locale_id
                            AND x.space_id  = @SpaceId
                        WHERE x.locale_id IS NULL;
                    END;
                END;

                SET @MRow = @MRow + 1;
            END; -- WHILE

            DROP TABLE #IncomingMedia;
        END; -- IF @MediaItems IS NOT NULL

        -- 6. Sync linked teleport button (approval only)
        --    Uses @OldMapSpotId captured at step 1 (before booth was updated)
        --    to find the button, then brings it in line with the new booth values.
        --    Skipped for draft saves, skipped when no button is linked.
        IF @ForceStatus = 'approved' AND @OldMapSpotId IS NOT NULL AND @MapSpotId IS NOT NULL
        BEGIN
            DECLARE @ButtonId      INT;
            DECLARE @ButtonNameKey UNIQUEIDENTIFIER;

            SELECT @ButtonId      = ttb.id,
                   @ButtonNameKey = ttb.name_key
            FROM   teleport_table_button ttb
            INNER JOIN teleport_table tt ON ttb.teleport_table_id = tt.id
            WHERE  tt.space_id     = @SpaceId
              AND  ttb.map_spot_id = @OldMapSpotId
              AND  ttb.is_deleted  = 0;

            IF @ButtonId IS NOT NULL
            BEGIN
                -- Sync map_spot_id and icon_key from booth (covers name-only, icon-only, and map-spot changes)
                UPDATE teleport_table_button
                SET    map_spot_id   = @MapSpotId,
                       icon_key      = ISNULL(@IconKey, icon_key),
                       modified_by   = ISNULL(@ModifiedBy, modified_by),
                       modified_time = SYSUTCDATETIME()
                WHERE  id = @ButtonId;

                -- Sync localized names using same 3-step pattern
                IF @I18nName IS NOT NULL
                BEGIN
                    -- Step a: soft-delete all current button name translations
                    UPDATE i18n SET is_deleted = 1
                    WHERE  [key]      = @ButtonNameKey
                      AND  space_id   = @SpaceId
                      AND  is_deleted = 0;

                    -- Step b-1: re-activate rows whose locale is in the payload
                    UPDATE i18n
                    SET    is_deleted = 0,
                           [value]    = j.[value]
                    FROM   i18n
                    INNER JOIN OPENJSON(@I18nName) WITH (
                        locale_id NVARCHAR(20)  '$.locale_id',
                        [value]   NVARCHAR(MAX) '$.value'
                    ) j ON i18n.locale_id = j.locale_id
                    WHERE  i18n.[key]    = @ButtonNameKey
                      AND  i18n.space_id = @SpaceId;

                    -- Step b-2: insert locales that have never had a physical row
                    INSERT INTO i18n ([key], locale_id, [value], space_id, created_by)
                    SELECT @ButtonNameKey, j.locale_id, j.[value], @SpaceId, @CreatedBy
                    FROM   OPENJSON(@I18nName) WITH (
                        locale_id NVARCHAR(20)  '$.locale_id',
                        [value]   NVARCHAR(MAX) '$.value'
                    ) j
                    LEFT JOIN i18n x
                        ON  x.[key]     = @ButtonNameKey
                        AND x.locale_id = j.locale_id
                        AND x.space_id  = @SpaceId
                    WHERE x.locale_id IS NULL;
                END;
            END;
        END; -- teleport sync

        COMMIT TRANSACTION;
        SELECT 1 AS found;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#IncomingMedia') IS NOT NULL DROP TABLE #IncomingMedia;
        THROW;
    END CATCH
END;
