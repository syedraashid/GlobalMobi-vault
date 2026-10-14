CREATE   PROCEDURE [dbo].[sp_Portal_GetByBooth_Unity]
    @SpaceId INT,
    @BoothId INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    SELECT
        p.id                          AS portal_id,
        p.space_id,
        p.booth_id,
        p.portal_type_id,
        p.event_id,
        cm.id                         AS corr_media_id,
        cm.media_type_id              AS corr_media_type_id,
        p.text_field_key              AS text_key,

        sl.locale_id,
        i.[value]                     AS localized_text_value,

        ml1.media_link                AS corr_media_link
    FROM portal p
    LEFT JOIN supported_languages sl
           ON sl.space_id = p.space_id
    LEFT JOIN i18n i
           ON i.[key]      = p.text_field_key
          AND i.space_id   = p.space_id
          AND i.locale_id  = sl.locale_id
          AND i.is_deleted = 0
    LEFT JOIN media cm
           ON cm.id         = p.corresponding_media_id
          AND cm.space_id   = p.space_id
          AND cm.is_deleted = 0
    LEFT JOIN media_localization ml1
           ON ml1.media_id   = p.corresponding_media_id
          AND ml1.locale_id  = sl.locale_id
          AND ml1.is_deleted = 0
    WHERE p.space_id  = @SpaceId
      AND p.booth_id  = @BoothId
      AND p.is_deleted = 0
      AND p.[status]   = 'approved'
    ORDER BY p.id, sl.locale_id;
END;
