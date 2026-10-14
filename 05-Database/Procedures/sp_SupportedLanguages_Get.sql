-- Returns supported locales for a space.
-- locale_id is returned as-is (en_us format) — consumers use Locale[] lookup with underscore keys.
-- display_name comes from i18n_locale (the single source of truth for language definitions).
CREATE   PROCEDURE [dbo].[sp_SupportedLanguages_Get]
    @SpaceId   INT,
    @LocaleIds NVARCHAR(MAX) = NULL   -- optional JSON string array
AS
BEGIN
    SET NOCOUNT ON;

    IF @LocaleIds IS NULL
    BEGIN
        -- Get-all mode: return every locale supported by this space (or global)
        SELECT
            sl.locale_id,
            ISNULL(il.language_name, sl.locale_id) AS display_name,
            sl.is_default
        FROM   [dbo].[supported_languages] sl
        LEFT JOIN [dbo].[i18n_locale] il ON il.id = sl.locale_id AND il.is_deleted = 0
        WHERE  (sl.space_id = @SpaceId OR sl.space_id IS NULL)
          AND  sl.is_deleted = 0;
    END
    ELSE
    BEGIN
        -- Validate mode: return only provided locales that are supported
        SELECT
            sl.locale_id,
            ISNULL(il.language_name, sl.locale_id) AS display_name,
            sl.is_default
        FROM   [dbo].[supported_languages] sl
        INNER JOIN OPENJSON(@LocaleIds) j
               ON  sl.locale_id = j.[value]
        LEFT JOIN [dbo].[i18n_locale] il ON il.id = sl.locale_id AND il.is_deleted = 0
        WHERE  (sl.space_id = @SpaceId OR sl.space_id IS NULL)
          AND  sl.is_deleted = 0;
    END
END;
