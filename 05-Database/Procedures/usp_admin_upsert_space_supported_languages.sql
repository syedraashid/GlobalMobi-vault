CREATE   PROCEDURE [dbo].[usp_admin_upsert_space_supported_languages]
    @SpaceId     INT,
    @LocalesJson NVARCHAR(MAX),
    @ModifiedBy  VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[supported_languages]
    SET    is_deleted    = 1,
           modified_time = SYSUTCDATETIME(),
           modified_by   = @ModifiedBy
    WHERE  space_id   = @SpaceId
      AND  is_deleted = 0;

    MERGE [dbo].[supported_languages] AS target
    USING (
        SELECT j.localeId, CAST(j.isDefault AS BIT) AS isDefault
        FROM   OPENJSON(@LocalesJson)
               WITH (localeId VARCHAR(10), isDefault BIT) j
        INNER JOIN [dbo].[i18n_locale] il
               ON il.id = j.localeId AND il.is_deleted = 0
    ) AS src
    ON  target.space_id  = @SpaceId
    AND target.locale_id = src.localeId
    WHEN MATCHED THEN
        UPDATE SET is_deleted    = 0,
                   is_default    = src.isDefault,
                   modified_time = SYSUTCDATETIME(),
                   modified_by   = @ModifiedBy
    WHEN NOT MATCHED THEN
        INSERT (space_id, locale_id, is_default, modified_by, created_by, created_time)
        VALUES (@SpaceId, src.localeId, src.isDefault, @ModifiedBy, @ModifiedBy, SYSUTCDATETIME());

    EXEC [dbo].[usp_admin_get_space_supported_languages] @SpaceId = @SpaceId;
END;
