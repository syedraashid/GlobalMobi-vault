CREATE   PROCEDURE [dbo].[sp_AdPortal_Apply]
    @SpaceId    INT,
    @AdId       INT,
    @Portal     NVARCHAR(MAX),
    @Status     VARCHAR(20),
    @ModifiedBy VARCHAR(36) = 'system'
AS
BEGIN
    SET NOCOUNT ON;
    IF @Portal IS NULL RETURN;
    SET @ModifiedBy = ISNULL(NULLIF(@ModifiedBy, ''), 'system');
    DECLARE @now DATETIME2(7) = SYSUTCDATETIME();

    DECLARE @LinksJson NVARCHAR(MAX) = JSON_QUERY(@Portal, '$.links');
    IF @LinksJson IS NULL OR NOT EXISTS (SELECT 1 FROM OPENJSON(@LinksJson))
    BEGIN
        EXEC dbo.sp_AdPortal_Remove @AdId = @AdId, @ModifiedBy = @ModifiedBy;
        RETURN;
    END

    DECLARE @Title NVARCHAR(MAX) = JSON_QUERY(@Portal, '$.title');
    DECLARE @Main  NVARCHAR(MAX) = JSON_QUERY(@Portal, '$.main_media');
    DECLARE @ReqPortalId INT              = TRY_CAST(JSON_VALUE(@Portal, '$.portal_id')  AS INT);
    DECLARE @ReqTitleKey UNIQUEIDENTIFIER = TRY_CAST(JSON_VALUE(@Portal, '$.title_key')  AS UNIQUEIDENTIFIER);
    DECLARE @ReqMainId   BIGINT           = TRY_CAST(JSON_VALUE(@Main,   '$.id')         AS BIGINT);
    DECLARE @MainType    INT              = TRY_CAST(JSON_VALUE(@Main,   '$.media_type_id') AS INT);
    DECLARE @MainLinks   NVARCHAR(MAX)    = JSON_QUERY(@Main, '$.links');


    DECLARE @PortalId INT, @TitleKey UNIQUEIDENTIFIER, @MainMediaId BIGINT;
    SELECT @PortalId = id, @TitleKey = text_field_key, @MainMediaId = corresponding_media_id
    FROM   portal WITH (UPDLOCK, HOLDLOCK)
    WHERE  ad_id = @AdId AND is_deleted = 0;


    CREATE TABLE #AdPortalReq
    (
        seq INT NOT NULL PRIMARY KEY, link_id INT NULL, position_id INT NULL, external_link NVARCHAR(MAX) NULL,
        thumb_json NVARCHAR(MAX) NULL, has_thumb BIT NOT NULL DEFAULT 0, thumb_id BIGINT NULL, thumb_type INT NULL, thumb_links NVARCHAR(MAX) NULL
    );
    INSERT #AdPortalReq (seq, link_id, position_id, external_link, thumb_json)
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), j.id, j.position_id, j.external_link, j.thumb
    FROM   OPENJSON(@LinksJson) WITH (
               id            INT           '$.id',
               position_id   INT           '$.position_id',
               external_link NVARCHAR(MAX) '$.external_link',
               thumb         NVARCHAR(MAX) '$.thumbnail' AS JSON) j;
    UPDATE #AdPortalReq
    SET    has_thumb   = CASE WHEN thumb_json IS NOT NULL THEN 1 ELSE 0 END,
           thumb_id    = TRY_CAST(JSON_VALUE(thumb_json, '$.id') AS BIGINT),
           thumb_type  = TRY_CAST(JSON_VALUE(thumb_json, '$.media_type_id') AS INT),
           thumb_links = JSON_QUERY(thumb_json, '$.links');


    IF ISNULL(@ReqPortalId, 0) > 0 AND ISNULL(@PortalId, 0) <> @ReqPortalId
        THROW 52113, 'A portal, link or media id does not belong to this ad''s portal.', 1;
    IF @PortalId IS NOT NULL AND @ReqTitleKey IS NOT NULL AND @ReqTitleKey <> @TitleKey
        THROW 52113, 'A portal, link or media id does not belong to this ad''s portal.', 1;
    IF ISNULL(@ReqMainId, 0) > 0 AND ISNULL(@MainMediaId, 0) <> @ReqMainId
        THROW 52113, 'A portal, link or media id does not belong to this ad''s portal.', 1;
    IF EXISTS (SELECT 1 FROM #AdPortalReq WHERE link_id > 0 GROUP BY link_id HAVING COUNT(*) > 1)
        THROW 52113, 'A portal, link or media id does not belong to this ad''s portal.', 1;
    IF EXISTS (SELECT 1 FROM #AdPortalReq r
               WHERE r.link_id > 0
                 AND NOT EXISTS (SELECT 1 FROM portal_link pl WHERE pl.id = r.link_id AND pl.portal_id = @PortalId AND pl.is_deleted = 0))
        THROW 52113, 'A portal, link or media id does not belong to this ad''s portal.', 1;

    IF EXISTS (SELECT 1 FROM #AdPortalReq r
               WHERE r.thumb_id > 0
                 AND (ISNULL(r.link_id, 0) = 0
                      OR NOT EXISTS (SELECT 1 FROM portal_link pl
                                     WHERE pl.id = r.link_id AND pl.portal_id = @PortalId AND pl.is_deleted = 0
                                       AND pl.thumbnail_media_id = r.thumb_id)))
        THROW 52113, 'A portal, link or media id does not belong to this ad''s portal.', 1;

    IF @PortalId IS NULL
    BEGIN
        INSERT INTO media (space_id, media_type_id, created_by, modified_by) VALUES (@SpaceId, ISNULL(@MainType, 1), @ModifiedBy, @ModifiedBy);
        SET @MainMediaId = CAST(SCOPE_IDENTITY() AS BIGINT);
        SET @TitleKey = NEWID();
        INSERT INTO portal (space_id, booth_id, portal_type_id, event_id, corresponding_media_id, text_field_key, status, ad_id,
                            created_by, created_time, modified_by, modified_time)
        VALUES (@SpaceId, NULL, 11, NULL, @MainMediaId, @TitleKey, @Status, @AdId, @ModifiedBy, @now, @ModifiedBy, @now);
        SET @PortalId = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        UPDATE portal SET status = @Status, modified_by = @ModifiedBy, modified_time = @now WHERE id = @PortalId;
        IF @MainType IS NOT NULL
            UPDATE media SET media_type_id = @MainType, modified_by = @ModifiedBy, modified_time = @now WHERE id = @MainMediaId AND media_type_id <> @MainType;
    END

    IF @Title IS NOT NULL
        EXEC dbo.sp_AdPortal_SetI18n @Key = @TitleKey, @SpaceId = @SpaceId, @Values = @Title, @ModifiedBy = @ModifiedBy;
    IF @MainLinks IS NOT NULL
        EXEC dbo.sp_AdPortal_SetMediaLinks @MediaId = @MainMediaId, @Links = @MainLinks, @ModifiedBy = @ModifiedBy;

    DECLARE @gone TABLE (link_id INT NOT NULL PRIMARY KEY, thumb BIGINT NULL);
    INSERT @gone (link_id, thumb)
    SELECT pl.id, pl.thumbnail_media_id
    FROM   portal_link pl
    WHERE  pl.portal_id = @PortalId AND pl.is_deleted = 0
      AND  NOT EXISTS (SELECT 1 FROM #AdPortalReq r WHERE r.link_id = pl.id);
    UPDATE ml SET ml.is_deleted = 1, ml.modified_by = @ModifiedBy, ml.modified_time = @now
    FROM media_localization ml INNER JOIN @gone g ON g.thumb = ml.media_id WHERE ml.is_deleted = 0;
    UPDATE m SET m.is_deleted = 1, m.modified_by = @ModifiedBy, m.modified_time = @now
    FROM media m INNER JOIN @gone g ON g.thumb = m.id WHERE m.is_deleted = 0;
    UPDATE pl SET pl.is_deleted = 1, pl.modified_by = @ModifiedBy, pl.modified_time = @now
    FROM portal_link pl INNER JOIN @gone g ON g.link_id = pl.id;

    DECLARE @lid INT, @pos INT, @ext NVARCHAR(MAX), @hasThumb BIT, @tid BIGINT, @ttype INT, @tlinks NVARCHAR(MAX), @newThumb BIGINT, @oldThumb BIGINT;
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT link_id, position_id, external_link, has_thumb, thumb_id, thumb_type, thumb_links FROM #AdPortalReq ORDER BY seq;
    OPEN c;
    FETCH NEXT FROM c INTO @lid, @pos, @ext, @hasThumb, @tid, @ttype, @tlinks;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF ISNULL(@lid, 0) > 0
        BEGIN
            SELECT @oldThumb = thumbnail_media_id FROM portal_link WHERE id = @lid;
            UPDATE portal_link
            SET    position_id = ISNULL(@pos, position_id), external_link = @ext, status = @Status,
                   modified_by = @ModifiedBy, modified_time = @now
            WHERE  id = @lid;

            IF @hasThumb = 1
            BEGIN
                IF ISNULL(@tid, 0) > 0
                BEGIN
                    IF @ttype IS NOT NULL
                        UPDATE media SET media_type_id = @ttype, modified_by = @ModifiedBy, modified_time = @now WHERE id = @tid AND media_type_id <> @ttype;
                    IF @tlinks IS NOT NULL
                        EXEC dbo.sp_AdPortal_SetMediaLinks @MediaId = @tid, @Links = @tlinks, @ModifiedBy = @ModifiedBy;
                END
                ELSE
                BEGIN
                    INSERT INTO media (space_id, media_type_id, created_by, modified_by) VALUES (@SpaceId, ISNULL(@ttype, 1), @ModifiedBy, @ModifiedBy);
                    SET @newThumb = CAST(SCOPE_IDENTITY() AS BIGINT);
                    IF @tlinks IS NOT NULL
                        EXEC dbo.sp_AdPortal_SetMediaLinks @MediaId = @newThumb, @Links = @tlinks, @ModifiedBy = @ModifiedBy;
                    UPDATE portal_link SET thumbnail_media_id = @newThumb WHERE id = @lid;
                    IF @oldThumb IS NOT NULL
                        EXEC dbo.sp_AdPortal_SoftDeleteMedia @MediaId = @oldThumb, @ModifiedBy = @ModifiedBy;
                END
            END
        END
        ELSE
        BEGIN
            SET @newThumb = NULL;
            IF @hasThumb = 1
            BEGIN
                INSERT INTO media (space_id, media_type_id, created_by, modified_by) VALUES (@SpaceId, ISNULL(@ttype, 1), @ModifiedBy, @ModifiedBy);
                SET @newThumb = CAST(SCOPE_IDENTITY() AS BIGINT);
                IF @tlinks IS NOT NULL
                    EXEC dbo.sp_AdPortal_SetMediaLinks @MediaId = @newThumb, @Links = @tlinks, @ModifiedBy = @ModifiedBy;
            END
            INSERT INTO portal_link (portal_id, position_id, external_link, thumbnail_media_id, status, created_by, created_time, modified_by, modified_time)
            VALUES (@PortalId, @pos, @ext, @newThumb, @Status, @ModifiedBy, @now, @ModifiedBy, @now);
        END
        FETCH NEXT FROM c INTO @lid, @pos, @ext, @hasThumb, @tid, @ttype, @tlinks;
    END
    CLOSE c; DEALLOCATE c;
END
