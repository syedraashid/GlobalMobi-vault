CREATE   PROCEDURE [dbo].[sp_AdPortal_SetI18n]
    @Key        UNIQUEIDENTIFIER,
    @SpaceId    INT,
    @Values     NVARCHAR(MAX),
    @ModifiedBy VARCHAR(36) = 'system'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @now DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @in TABLE (locale_id VARCHAR(10) NOT NULL PRIMARY KEY, [value] VARCHAR(MAX) NOT NULL);

    IF @Values IS NOT NULL
        INSERT @in (locale_id, [value])
        SELECT x.locale_id, x.[value]
        FROM (SELECT JSON_VALUE(v.[value], '$.locale_id') AS locale_id,
                     (SELECT j.[value] FROM OPENJSON(v.[value]) j WHERE j.[key] = 'value') AS [value],
                     ROW_NUMBER() OVER (PARTITION BY JSON_VALUE(v.[value], '$.locale_id') ORDER BY CAST(v.[key] AS INT) DESC) AS rn
              FROM OPENJSON(@Values) v) x
        WHERE x.rn = 1 AND ISNULL(x.locale_id, '') <> '' AND x.[value] IS NOT NULL;

    UPDATE i18n
    SET    is_deleted = 1, modified_by = @ModifiedBy, modified_time = @now
    WHERE  [key] = @Key AND space_id = @SpaceId AND is_deleted = 0;

    UPDATE t
    SET    t.is_deleted = 0, t.[value] = i.[value], t.modified_by = @ModifiedBy, t.modified_time = @now
    FROM   i18n t
    INNER JOIN @in i ON i.locale_id = t.locale_id
    WHERE  t.[key] = @Key AND t.space_id = @SpaceId;

    INSERT INTO i18n ([key], locale_id, [value], space_id, created_by, created_time, modified_by, modified_time)
    SELECT @Key, i.locale_id, i.[value], @SpaceId, @ModifiedBy, @now, @ModifiedBy, @now
    FROM   @in i
    WHERE  NOT EXISTS (SELECT 1 FROM i18n x WHERE x.[key] = @Key AND x.locale_id = i.locale_id);
END
