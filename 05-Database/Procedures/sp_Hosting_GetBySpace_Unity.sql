CREATE   PROCEDURE [dbo].[sp_Hosting_GetBySpace_Unity]
    @SpaceId INT,
    @Active  BIT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    SELECT
        h.id,
        h.space_id,
        h.name_key,
        h.stream_url,
        h.is_active,
        h.modified_time,
        h.modified_by,
        iname.locale_id AS locale_id,
        iname.[value]   AS name_value
    FROM hosting h
    LEFT JOIN i18n AS iname
           ON iname.[key]      = h.name_key
          AND iname.space_id   = @SpaceId
          AND iname.is_deleted = 0
    WHERE h.space_id   = @SpaceId
      AND h.is_deleted = 0
      AND h.[status]   = 'approved'
      AND (@Active IS NULL OR h.is_active = @Active)
    ORDER BY h.id, iname.locale_id;
END;
