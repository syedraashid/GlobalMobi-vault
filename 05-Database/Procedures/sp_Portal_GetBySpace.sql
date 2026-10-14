CREATE   PROCEDURE [dbo].[sp_Portal_GetBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.id                          AS portal_id,
        p.space_id,
        p.booth_id,
        p.portal_type_id,
        p.event_id,
        cm.id                         AS corr_media_id,
        p.text_field_key              AS text_key,

        sl.locale_id,
        i.[value]                     AS localized_text_value,

        cm.media_type_id              AS corr_media_type_id,
        ml1.media_link                AS corr_media_link,
        COALESCE(ca.[status], p.[status]) AS approval_status,
        ca.id                         AS approval_id,
        ca.[action_type]              AS approval_action_type,
        ca.[current_snapshot]         AS current_snapshot,
        ca.[proposed_snapshot]        AS proposed_snapshot,
        p.[status]                    AS content_status
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
    LEFT JOIN dbo.content_approval ca
        ON  ca.content_type = 'portal'
       AND  ca.content_id   = p.id
       AND  ca.[status]    != 'withdrawn'
    WHERE p.space_id = @SpaceId
      AND p.is_deleted = 0
      AND p.ad_id IS NULL
    ORDER BY p.id, sl.locale_id;
END
