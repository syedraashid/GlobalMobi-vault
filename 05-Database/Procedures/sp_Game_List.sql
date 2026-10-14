CREATE   PROCEDURE [dbo].[sp_Game_List]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT g.id,
           g.name_key                AS NameKey,
           g.description_key         AS DescriptionKey,
           g.game_code               AS GameCode,
           g.sort_order              AS SortOrder,
           CAST(g.is_active AS INT)  AS IsActive,
           ln.locale_id AS name_locale_id, ln.[value] AS name_value,
           ld.locale_id AS desc_locale_id, ld.[value] AS desc_value
    FROM dbo.game g
    OUTER APPLY (
        SELECT locale_id FROM i18n WHERE [key] = g.name_key AND is_deleted = 0
        UNION
        SELECT locale_id FROM i18n WHERE [key] = g.description_key AND is_deleted = 0
    ) locs
    LEFT JOIN i18n ln ON ln.[key] = g.name_key AND ln.locale_id = locs.locale_id AND ln.is_deleted = 0
    LEFT JOIN i18n ld ON ld.[key] = g.description_key AND ld.locale_id = locs.locale_id AND ld.is_deleted = 0
    WHERE g.is_deleted = 0
    ORDER BY g.sort_order, g.id, locs.locale_id;
END;
