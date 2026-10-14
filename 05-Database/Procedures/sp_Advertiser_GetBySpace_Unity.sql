CREATE   PROCEDURE [dbo].[sp_Advertiser_GetBySpace_Unity]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    SELECT
        a.id,
        a.space_id,
        a.name_key,
        a.is_active,
        a.industry,
        a.modified_time,
        a.modified_by,
        iname.locale_id AS locale_id,
        iname.[value]   AS name_value
    FROM advertiser a
    LEFT JOIN i18n AS iname
           ON iname.[key]      = a.name_key
          AND iname.space_id   = @SpaceId
          AND iname.is_deleted = 0
    WHERE a.space_id   = @SpaceId
      AND a.is_deleted = 0
      AND a.[status]   = 'approved'
      AND a.is_active  = 1
    ORDER BY a.id, iname.locale_id;
END;
