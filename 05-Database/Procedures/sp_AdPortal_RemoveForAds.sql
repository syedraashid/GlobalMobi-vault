CREATE   PROCEDURE [dbo].[sp_AdPortal_RemoveForAds]
    @ModifiedBy VARCHAR(36) = 'system'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @now DATETIME2(7) = SYSUTCDATETIME();

    DECLARE @portals TABLE (portal_id INT NOT NULL PRIMARY KEY, space_id INT NOT NULL, text_key UNIQUEIDENTIFIER NOT NULL, main_media BIGINT NOT NULL);
    INSERT @portals (portal_id, space_id, text_key, main_media)
    SELECT p.id, p.space_id, p.text_field_key, p.corresponding_media_id
    FROM   portal p
    INNER JOIN #AdPortalTargets t ON t.ad_id = p.ad_id
    WHERE  p.is_deleted = 0;

    IF NOT EXISTS (SELECT 1 FROM @portals) RETURN;

    DECLARE @thumbs TABLE (media_id BIGINT NOT NULL PRIMARY KEY);
    INSERT @thumbs (media_id)
    SELECT DISTINCT pl.thumbnail_media_id
    FROM   portal_link pl
    INNER JOIN @portals x ON x.portal_id = pl.portal_id
    WHERE  pl.is_deleted = 0 AND pl.thumbnail_media_id IS NOT NULL;

    -- 1. thumbnails
    UPDATE ml SET ml.is_deleted = 1, ml.modified_by = @ModifiedBy, ml.modified_time = @now
    FROM media_localization ml INNER JOIN @thumbs t ON t.media_id = ml.media_id WHERE ml.is_deleted = 0;
    UPDATE m SET m.is_deleted = 1, m.modified_by = @ModifiedBy, m.modified_time = @now
    FROM media m INNER JOIN @thumbs t ON t.media_id = m.id WHERE m.is_deleted = 0;

    -- 2. links
    UPDATE pl SET pl.is_deleted = 1, pl.modified_by = @ModifiedBy, pl.modified_time = @now
    FROM portal_link pl INNER JOIN @portals x ON x.portal_id = pl.portal_id WHERE pl.is_deleted = 0;

    -- 3. title text
    UPDATE i SET i.is_deleted = 1, i.modified_by = @ModifiedBy, i.modified_time = @now
    FROM i18n i INNER JOIN @portals x ON x.text_key = i.[key] AND x.space_id = i.space_id WHERE i.is_deleted = 0;

    -- 4. the portal row
    UPDATE p SET p.is_deleted = 1, p.modified_by = @ModifiedBy, p.modified_time = @now
    FROM portal p INNER JOIN @portals x ON x.portal_id = p.id;

    -- 5. main media
    UPDATE ml SET ml.is_deleted = 1, ml.modified_by = @ModifiedBy, ml.modified_time = @now
    FROM media_localization ml INNER JOIN @portals x ON x.main_media = ml.media_id WHERE ml.is_deleted = 0;
    UPDATE m SET m.is_deleted = 1, m.modified_by = @ModifiedBy, m.modified_time = @now
    FROM media m INNER JOIN @portals x ON x.main_media = m.id WHERE m.is_deleted = 0;
END
