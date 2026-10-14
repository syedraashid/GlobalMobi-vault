CREATE   PROCEDURE [dbo].[usp_admin_get_space_supported_languages]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        sl.locale_id                            AS LocaleId,
        ISNULL(il.language_name, sl.locale_id) AS DisplayName,
        sl.is_default                           AS IsDefault
    FROM   [dbo].[supported_languages] sl
    LEFT JOIN [dbo].[i18n_locale] il
           ON il.id = sl.locale_id AND il.is_deleted = 0
    WHERE  sl.space_id  = @SpaceId
      AND  sl.is_deleted = 0
    ORDER BY sl.is_default DESC, il.language_name;
END;
