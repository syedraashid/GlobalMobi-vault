CREATE   PROCEDURE [dbo].[sp_Portal_GetByBoothIds]
    @SpaceId  INT,
    @BoothIds NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.id                         AS portal_id,
        p.space_id,
        p.booth_id,
        p.portal_type_id,
        p.event_id,
        cm.id                        AS corr_media_id,
        cm.media_type_id             AS corr_media_type_id,
        p.text_field_key             AS text_key,
        sl.locale_id,
        i.[value]                    AS localized_text_value,
        ml1.media_link               AS corr_media_link,
        p.created_time               AS created_at,
        ca.approval_id,
        ca.approval_status,
        ca.approval_action_type,
        ca.current_snapshot,
        ca.proposed_snapshot,
        p.[status]                   AS content_status
    FROM portal p
    JOIN (SELECT CAST([value] AS INT) AS id FROM OPENJSON(@BoothIds)) ids
        ON ids.id = p.booth_id
    LEFT JOIN supported_languages sl
        ON sl.space_id = p.space_id
    LEFT JOIN i18n i
        ON  i.[key]      = p.text_field_key
        AND i.space_id   = p.space_id
        AND i.locale_id  = sl.locale_id
        AND i.is_deleted = 0
    LEFT JOIN media cm
        ON  cm.id         = p.corresponding_media_id
        AND cm.space_id   = p.space_id
        AND cm.is_deleted = 0
    LEFT JOIN media_localization ml1
        ON  ml1.media_id   = p.corresponding_media_id
        AND ml1.locale_id  = sl.locale_id
        AND ml1.is_deleted = 0
    OUTER APPLY (
        SELECT TOP 1
            ca.id               AS approval_id,
            ca.[status]         AS approval_status,
            ca.action_type      AS approval_action_type,
            ca.[current_snapshot]  AS current_snapshot,
            ca.[proposed_snapshot] AS proposed_snapshot
        FROM  content_approval ca WITH (NOLOCK)
        WHERE ca.content_type = 'portal'
          AND ca.content_id   = p.id
          AND ca.[status]    != 'withdrawn'
        ORDER BY ca.submitted_at DESC
    ) ca
    WHERE p.space_id   = @SpaceId
      AND p.is_deleted = 0
    ORDER BY p.booth_id, p.id, sl.locale_id;
END;
