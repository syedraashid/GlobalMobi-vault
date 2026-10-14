CREATE   PROCEDURE [dbo].[sp_AdPortal_SetMediaLinks]
    @MediaId    BIGINT,
    @Links      NVARCHAR(MAX),
    @ModifiedBy VARCHAR(36) = 'system'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @now DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @in TABLE (locale_id VARCHAR(10) NOT NULL PRIMARY KEY, media_link VARCHAR(255) NOT NULL);

    IF @Links IS NOT NULL
        INSERT @in (locale_id, media_link)
        SELECT x.locale_id, x.media_link
        FROM (SELECT JSON_VALUE(v.[value], '$.locale_id')  AS locale_id,
                     JSON_VALUE(v.[value], '$.media_link') AS media_link,
                     ROW_NUMBER() OVER (PARTITION BY JSON_VALUE(v.[value], '$.locale_id') ORDER BY CAST(v.[key] AS INT) DESC) AS rn
              FROM OPENJSON(@Links) v) x
        WHERE x.rn = 1 AND ISNULL(x.locale_id, '') <> '' AND ISNULL(x.media_link, '') <> '';

    UPDATE media_localization
    SET    is_deleted = 1, modified_by = @ModifiedBy, modified_time = @now
    WHERE  media_id = @MediaId AND is_deleted = 0;

    UPDATE ml
    SET    ml.is_deleted = 0, ml.media_link = i.media_link, ml.modified_by = @ModifiedBy, ml.modified_time = @now
    FROM   media_localization ml
    INNER JOIN @in i ON i.locale_id = ml.locale_id
    WHERE  ml.media_id = @MediaId;

    INSERT INTO media_localization (media_id, locale_id, media_link, created_by, created_time, modified_by, modified_time)
    SELECT @MediaId, i.locale_id, i.media_link, @ModifiedBy, @now, @ModifiedBy, @now
    FROM   @in i
    WHERE  NOT EXISTS (SELECT 1 FROM media_localization x WHERE x.media_id = @MediaId AND x.locale_id = i.locale_id);
END
