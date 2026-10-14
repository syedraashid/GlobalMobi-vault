CREATE   PROCEDURE [dbo].[sp_Hosting_GetById_Unity]
    @SpaceId   INT,
    @HostingId INT
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
    WHERE h.id         = @HostingId
      AND h.space_id   = @SpaceId
      AND h.is_deleted = 0
      AND h.[status]   = 'approved'
    ORDER BY iname.locale_id;
END;
