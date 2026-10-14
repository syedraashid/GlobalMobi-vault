CREATE   PROCEDURE [dbo].[sp_Portal_Update]
    @SpaceId            INT,
    @PortalId           INT,
    @BoothId            INT           = NULL,
    @PortalTypeId       INT           = NULL,
    @EventId            INT           = NULL,
    @ModifiedBy         NVARCHAR(255) = NULL,
    @I18nValues         NVARCHAR(MAX) = NULL,
    @CorrespMedia       NVARCHAR(MAX) = NULL,
    @RemoveCorrespMedia BIT           = 0,
    @PortalLinks        NVARCHAR(MAX) = NULL,
    @ForceStatus        VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TextFieldKey   UNIQUEIDENTIFIER;
        DECLARE @CurrentMediaId BIGINT;

        SELECT
            @TextFieldKey   = text_field_key,
            @CurrentMediaId = corresponding_media_id
        FROM portal WITH (UPDLOCK, ROWLOCK, HOLDLOCK)
        WHERE id       = @PortalId
          AND space_id = @SpaceId
          AND (@BoothId IS NULL OR booth_id = @BoothId)
          AND is_deleted = 0
          AND ad_id IS NULL;

        IF @TextFieldKey IS NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS found;
            RETURN;
        END;
        UPDATE portal
        SET portal_type_id = COALESCE(@PortalTypeId, portal_type_id),
            event_id       = COALESCE(@EventId,       event_id),
            modified_by    = ISNULL(@ModifiedBy, 'system'),
            modified_time  = SYSUTCDATETIME(),
            [status]       = ISNULL(@ForceStatus, [status])
        WHERE id       = @PortalId
          AND space_id = @SpaceId
          AND (@BoothId IS NULL OR booth_id = @BoothId);

        UPDATE portal_link
        SET    [status] = ISNULL(@ForceStatus, [status])
        WHERE  portal_id = @PortalId;

        IF @I18nValues IS NOT NULL
        BEGIN
            UPDATE i18n
            SET    is_deleted = 1
            WHERE  [key]      = @TextFieldKey
              AND  space_id   = @SpaceId
              AND  is_deleted = 0;

            UPDATE i18n
            SET    is_deleted = 0,
                   [value]    = j.[value]
            FROM   i18n
            INNER JOIN OPENJSON(@I18nValues) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j ON i18n.locale_id = j.locale_id
            WHERE  i18n.[key]    = @TextFieldKey
              AND  i18n.space_id = @SpaceId;

            INSERT INTO i18n ([key], locale_id, [value], space_id)
            SELECT @TextFieldKey, j.locale_id, j.[value], @SpaceId
            FROM   OPENJSON(@I18nValues) WITH (
                locale_id NVARCHAR(20)  '$.locale_id',
                [value]   NVARCHAR(MAX) '$.value'
            ) j
            LEFT JOIN i18n x
                ON  x.[key]     = @TextFieldKey
                AND x.locale_id = j.locale_id
                AND x.space_id  = @SpaceId
            WHERE  x.locale_id IS NULL;
        END;


        IF @CorrespMedia IS NULL AND @RemoveCorrespMedia = 1
        BEGIN
            IF @CurrentMediaId IS NOT NULL
            BEGIN
                UPDATE portal
                SET    corresponding_media_id = NULL
                WHERE  id       = @PortalId
                  AND  space_id = @SpaceId
                  AND  (@BoothId IS NULL OR booth_id = @BoothId);

                UPDATE media_localization
                SET    is_deleted = 1
                WHERE  media_id   = @CurrentMediaId;

                UPDATE media
                SET    is_deleted = 1
                WHERE  id         = @CurrentMediaId
                  AND  space_id   = @SpaceId;
            END;
        END
        ELSE IF @CorrespMedia IS NOT NULL
        BEGIN
            DECLARE @MediaId      BIGINT        = CAST(JSON_VALUE(@CorrespMedia, '$.id')            AS BIGINT);
            DECLARE @MediaTypeId  INT           = CAST(JSON_VALUE(@CorrespMedia, '$.media_type_id') AS INT);
            DECLARE @MediaTextKey NVARCHAR(MAX) =      JSON_VALUE(@CorrespMedia, '$.text_key');
            DECLARE @MediaDescKey NVARCHAR(MAX) =      JSON_VALUE(@CorrespMedia, '$.description_key');
            DECLARE @MediaLocs    NVARCHAR(MAX) =      JSON_QUERY(@CorrespMedia, '$.link_localizations');

            IF @MediaId IS NOT NULL AND (
                   EXISTS (SELECT 1 FROM portal ap WHERE ap.ad_id IS NOT NULL AND ap.corresponding_media_id = @MediaId)
                OR EXISTS (SELECT 1 FROM portal_link apl INNER JOIN portal ap2 ON ap2.id = apl.portal_id WHERE ap2.ad_id IS NOT NULL AND apl.thumbnail_media_id = @MediaId))
                THROW 50001, 'Media record not found in this space or is already deleted.', 1;

            UPDATE portal
            SET    corresponding_media_id = @MediaId
            WHERE  id       = @PortalId
              AND  space_id = @SpaceId
              AND  (@BoothId IS NULL OR booth_id = @BoothId);

            UPDATE media
            SET    media_type_id   = @MediaTypeId,
                   text_key        = TRY_CAST(@MediaTextKey AS UNIQUEIDENTIFIER),
                   description_key = TRY_CAST(@MediaDescKey AS UNIQUEIDENTIFIER)
            WHERE  id         = @MediaId
              AND  space_id   = @SpaceId
              AND  is_deleted = 0;

            IF @@ROWCOUNT = 0
                THROW 50001, 'Media record not found in this space or is already deleted.', 1;


            UPDATE media_localization
            SET    is_deleted = 1
            WHERE  media_id   = @MediaId
              AND  is_deleted = 0;

            UPDATE media_localization
            SET    is_deleted = 0,
                   media_link = j.media_link
            FROM   media_localization
            INNER JOIN OPENJSON(@MediaLocs) WITH (
                locale_id  NVARCHAR(20)  '$.locale_id',
                media_link NVARCHAR(MAX) '$.media_link'
            ) j ON media_localization.locale_id = j.locale_id
            WHERE  media_localization.media_id = @MediaId;

            INSERT INTO media_localization (media_id, locale_id, media_link)
            SELECT @MediaId, j.locale_id, j.media_link
            FROM   OPENJSON(@MediaLocs) WITH (
                locale_id  NVARCHAR(20)  '$.locale_id',
                media_link NVARCHAR(MAX) '$.media_link'
            ) j
            LEFT JOIN media_localization x
                ON  x.media_id  = @MediaId
                AND x.locale_id = j.locale_id
            WHERE  x.locale_id IS NULL;
        END;


        IF @PortalLinks IS NOT NULL
        BEGIN

            CREATE TABLE #ExistingLinks (
                link_id        INT   NOT NULL PRIMARY KEY,
                thumb_media_id BIGINT NULL
            );

            INSERT INTO #ExistingLinks (link_id, thumb_media_id)
            SELECT id, thumbnail_media_id
            FROM   portal_link
            WHERE  portal_id  = @PortalId
              AND  is_deleted = 0;


            CREATE TABLE #IncomingLinks (
                row_num           INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
                link_id           INT           NOT NULL,
                position_id       INT           NULL,
                external_link     NVARCHAR(MAX) NULL,
                thumb_action      NVARCHAR(10)  NOT NULL,
                thumb_id          BIGINT        NULL,
                thumb_media_type  INT           NULL,
                thumb_text_key    NVARCHAR(MAX) NULL,
                thumb_desc_key    NVARCHAR(MAX) NULL,
                thumb_locs        NVARCHAR(MAX) NULL
            );

            INSERT INTO #IncomingLinks
                (link_id, position_id, external_link, thumb_action,
                 thumb_id, thumb_media_type, thumb_text_key, thumb_desc_key, thumb_locs)
            SELECT
                CAST(JSON_VALUE(value, '$.id')               AS INT),
                CAST(JSON_VALUE(value, '$.position_id')      AS INT),
                     JSON_VALUE(value, '$.external_link'),
                ISNULL(JSON_VALUE(value, '$.thumb_action'), 'none'),
                CAST(JSON_VALUE(value, '$.thumb_id')         AS BIGINT),
                CAST(JSON_VALUE(value, '$.thumb_media_type_id') AS INT),
                     JSON_VALUE(value, '$.thumb_text_key'),
                     JSON_VALUE(value, '$.thumb_desc_key'),
                     JSON_QUERY(value, '$.thumb_locs')
            FROM OPENJSON(@PortalLinks);


            UPDATE media_localization
            SET    is_deleted = 1
            FROM   media_localization ml
            INNER JOIN #ExistingLinks el ON el.thumb_media_id = ml.media_id
            WHERE  el.link_id NOT IN (SELECT link_id FROM #IncomingLinks WHERE link_id > 0)
              AND  el.thumb_media_id IS NOT NULL;

            UPDATE media
            SET    is_deleted = 1
            FROM   media m
            INNER JOIN #ExistingLinks el ON el.thumb_media_id = m.id
            WHERE  el.link_id NOT IN (SELECT link_id FROM #IncomingLinks WHERE link_id > 0)
              AND  el.thumb_media_id IS NOT NULL;

            UPDATE portal_link
            SET    is_deleted = 1
            FROM   portal_link pl
            INNER JOIN #ExistingLinks el ON el.link_id = pl.id
            WHERE  el.link_id NOT IN (SELECT link_id FROM #IncomingLinks WHERE link_id > 0);


            DECLARE @Row          INT = 1;
            DECLARE @MaxRow       INT = (SELECT COUNT(1) FROM #IncomingLinks);
            DECLARE @LnkId        INT;
            DECLARE @PosId        INT;
            DECLARE @ExtLink      NVARCHAR(MAX);
            DECLARE @ThumbAction  NVARCHAR(10);
            DECLARE @ThumbId      BIGINT;
            DECLARE @ThumbType    INT;
            DECLARE @ThumbTxtKey  NVARCHAR(MAX);
            DECLARE @ThumbDescKey NVARCHAR(MAX);
            DECLARE @ThumbLocs    NVARCHAR(MAX);
            DECLARE @OldThumbId   BIGINT;
            DECLARE @NewThumbId   BIGINT;

            WHILE @Row <= @MaxRow
            BEGIN

                SET @OldThumbId = NULL;
                SET @NewThumbId = NULL;

                SELECT
                    @LnkId        = link_id,
                    @PosId        = position_id,
                    @ExtLink      = external_link,
                    @ThumbAction  = thumb_action,
                    @ThumbId      = thumb_id,
                    @ThumbType    = thumb_media_type,
                    @ThumbTxtKey  = thumb_text_key,
                    @ThumbDescKey = thumb_desc_key,
                    @ThumbLocs    = thumb_locs
                FROM #IncomingLinks
                WHERE row_num = @Row;

                IF @LnkId > 0
                BEGIN
                    UPDATE portal_link
                    SET    position_id   = @PosId,
                           external_link = @ExtLink
                    WHERE  id         = @LnkId
                      AND  portal_id  = @PortalId
                      AND  is_deleted = 0;

                    IF @ThumbAction = 'remove'
                    BEGIN

                        SELECT @OldThumbId = thumb_media_id
                        FROM   #ExistingLinks
                        WHERE  link_id = @LnkId;

                        IF @OldThumbId IS NOT NULL
                        BEGIN
                            UPDATE portal_link
                            SET    thumbnail_media_id = NULL
                            WHERE  id        = @LnkId
                              AND  portal_id = @PortalId;

                            UPDATE media_localization SET is_deleted = 1 WHERE media_id = @OldThumbId;
                            UPDATE media SET is_deleted = 1 WHERE id = @OldThumbId AND space_id = @SpaceId;
                        END;
                    END
                    ELSE IF @ThumbAction = 'update'
                    BEGIN
                        IF @ThumbId IS NOT NULL AND (
                               EXISTS (SELECT 1 FROM portal ap WHERE ap.ad_id IS NOT NULL AND ap.corresponding_media_id = @ThumbId)
                            OR EXISTS (SELECT 1 FROM portal_link apl INNER JOIN portal ap2 ON ap2.id = apl.portal_id WHERE ap2.ad_id IS NOT NULL AND apl.thumbnail_media_id = @ThumbId))
                            THROW 50001, 'Media record not found in this space or is already deleted.', 1;


                        UPDATE media
                        SET    media_type_id   = @ThumbType,
                               text_key        = TRY_CAST(@ThumbTxtKey  AS UNIQUEIDENTIFIER),
                               description_key = TRY_CAST(@ThumbDescKey AS UNIQUEIDENTIFIER)
                        WHERE  id       = @ThumbId
                          AND  space_id = @SpaceId;

                        UPDATE media_localization
                        SET    is_deleted = 1
                        WHERE  media_id   = @ThumbId
                          AND  is_deleted = 0;

                        UPDATE media_localization
                        SET    is_deleted = 0,
                               media_link = j.media_link
                        FROM   media_localization
                        INNER JOIN OPENJSON(@ThumbLocs) WITH (
                            locale_id  NVARCHAR(20)  '$.locale_id',
                            media_link NVARCHAR(MAX) '$.media_link'
                        ) j ON media_localization.locale_id = j.locale_id
                        WHERE  media_localization.media_id = @ThumbId;

                        INSERT INTO media_localization (media_id, locale_id, media_link)
                        SELECT @ThumbId, j.locale_id, j.media_link
                        FROM   OPENJSON(@ThumbLocs) WITH (
                            locale_id  NVARCHAR(20)  '$.locale_id',
                            media_link NVARCHAR(MAX) '$.media_link'
                        ) j
                        LEFT JOIN media_localization x
                            ON  x.media_id  = @ThumbId
                            AND x.locale_id = j.locale_id
                        WHERE  x.locale_id IS NULL;

                        UPDATE portal_link
                        SET    thumbnail_media_id = @ThumbId
                        WHERE  id         = @LnkId
                          AND  portal_id  = @PortalId
                          AND  is_deleted = 0;
                    END
                    ELSE IF @ThumbAction = 'insert'
                    BEGIN

                        IF EXISTS (
                            SELECT 1
                            FROM   OPENJSON(@ThumbLocs) WITH (locale_id NVARCHAR(20) '$.locale_id') j
                            JOIN   supported_languages sl
                                ON sl.locale_id = j.locale_id
                               AND sl.space_id  = @SpaceId
                        )
                        BEGIN
                            INSERT INTO media (space_id, media_type_id, text_key, description_key)
                            VALUES (@SpaceId, @ThumbType,
                                    TRY_CAST(@ThumbTxtKey  AS UNIQUEIDENTIFIER),
                                    TRY_CAST(@ThumbDescKey AS UNIQUEIDENTIFIER));

                            SET @NewThumbId = SCOPE_IDENTITY();

                            INSERT INTO media_localization (media_id, locale_id, media_link)
                            SELECT @NewThumbId, j.locale_id, j.media_link
                            FROM   OPENJSON(@ThumbLocs) WITH (
                                locale_id  NVARCHAR(20)  '$.locale_id',
                                media_link NVARCHAR(MAX) '$.media_link'
                            ) j
                            JOIN   supported_languages sl
                                ON sl.locale_id = j.locale_id
                               AND sl.space_id  = @SpaceId;

                            UPDATE portal_link
                            SET    thumbnail_media_id = @NewThumbId
                            WHERE  id         = @LnkId
                              AND  portal_id  = @PortalId
                              AND  is_deleted = 0;
                        END;
                    END;
                END

                ELSE
                BEGIN
                    IF @ThumbAction = 'insert' AND @ThumbLocs IS NOT NULL
                    BEGIN
                        IF EXISTS (
                            SELECT 1
                            FROM   OPENJSON(@ThumbLocs) WITH (locale_id NVARCHAR(20) '$.locale_id') j
                            JOIN   supported_languages sl
                                ON sl.locale_id = j.locale_id
                               AND sl.space_id  = @SpaceId
                        )
                        BEGIN
                            INSERT INTO media (space_id, media_type_id, text_key, description_key)
                            VALUES (@SpaceId, @ThumbType,
                                    TRY_CAST(@ThumbTxtKey  AS UNIQUEIDENTIFIER),
                                    TRY_CAST(@ThumbDescKey AS UNIQUEIDENTIFIER));

                            SET @NewThumbId = SCOPE_IDENTITY();

                            INSERT INTO media_localization (media_id, locale_id, media_link)
                            SELECT @NewThumbId, j.locale_id, j.media_link
                            FROM   OPENJSON(@ThumbLocs) WITH (
                                locale_id  NVARCHAR(20)  '$.locale_id',
                                media_link NVARCHAR(MAX) '$.media_link'
                            ) j
                            JOIN   supported_languages sl
                                ON sl.locale_id = j.locale_id
                               AND sl.space_id  = @SpaceId;
                        END;
                    END;

                    INSERT INTO portal_link (portal_id, position_id, external_link, thumbnail_media_id)
                    VALUES (@PortalId, @PosId, @ExtLink, @NewThumbId);
                END;

                SET @Row = @Row + 1;
            END;

            DROP TABLE #ExistingLinks;
            DROP TABLE #IncomingLinks;

        END;

        COMMIT TRANSACTION;
        SELECT 1 AS found;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#ExistingLinks') IS NOT NULL DROP TABLE #ExistingLinks;
        IF OBJECT_ID('tempdb..#IncomingLinks') IS NOT NULL DROP TABLE #IncomingLinks;
        THROW;
    END CATCH
END;
