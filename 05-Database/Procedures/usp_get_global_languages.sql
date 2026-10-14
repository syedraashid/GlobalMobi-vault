-- Returns all available languages from i18n_locale — the single global source of truth.
-- Used by the entity config language dropdown. No entity_id needed since this list is global.
-- Returns the raw i18n_locale.id (e.g. 'en_us') as LocaleId so the frontend can send it
-- directly on PUT /config without any conversion.
CREATE   PROCEDURE [dbo].[usp_get_global_languages]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        id            AS LocaleId,
        language_name AS DisplayName
    FROM [dbo].[i18n_locale]
    WHERE is_deleted = 0
    ORDER BY language_name;
END;
