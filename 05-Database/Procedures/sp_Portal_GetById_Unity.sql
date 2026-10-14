CREATE   PROCEDURE [dbo].[sp_Portal_GetById_Unity]
    @SpaceId  INT,
    @PortalId INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    SELECT
        p.id                          AS portal_id,
        p.space_id,
        p.booth_id,
        p.portal_type_id,
        p.event_id,
        p.text_field_key              AS text_key,

        cm.id                         AS corr_media_id,
        cm.media_type_id              AS corr_media_type_id,

        i.locale_id                   AS locale_id,
        i.[value]                     AS localized_text_value,

        ml1.media_link                AS corresponding_media_link
    FROM portal p
    LEFT JOIN media cm
           ON cm.id         = p.corresponding_media_id
          AND cm.space_id   = p.space_id
          AND cm.is_deleted = 0
    LEFT JOIN i18n i
           ON i.[key]      = p.text_field_key
          AND i.space_id   = p.space_id
          AND i.is_deleted = 0
    LEFT JOIN media_localization ml1
           ON ml1.media_id   = p.corresponding_media_id
          AND ml1.locale_id  = i.locale_id
          AND ml1.is_deleted = 0
    WHERE p.id        = @PortalId
      AND p.space_id  = @SpaceId
      AND p.is_deleted = 0
      AND p.[status]   = 'approved'
      AND p.ad_id IS NULL
    ORDER BY i.locale_id;
END;
