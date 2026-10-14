------------------------------------------------------------------------
-- 1) sp_Charity_GetById  (CMS single charity)
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_Charity_GetById]
    @SpaceId   INT,
    @CharityId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.id,
        c.space_id,
        c.name_key,
        c.description_key,
        c.website_url,
        c.logo_media_id,
        c.donation_url,
        c.is_active,
        c.modified_time,
        c.modified_by,
        c.created_time,

        m.media_type_id           AS media_type_id,
        m.text_key                AS media_text_key,
        m.description_key         AS media_desc_key,

        locs.locale_id            AS locale_id,
        iname.[value]             AS name_value,
        idesc.[value]             AS description_value,
        ml.media_link             AS media_link,
        COALESCE(ca.[status], c.[status]) AS approval_status,
        ca.id                     AS approval_id,
        ca.[action_type]          AS approval_action_type,
        ca.[current_snapshot]     AS current_snapshot,
        ca.[proposed_snapshot]    AS proposed_snapshot,
        c.[status]                AS content_status
    FROM charity c
    OUTER APPLY (
        SELECT n.locale_id FROM i18n n
        WHERE  n.[key] = c.name_key        AND n.space_id = @SpaceId AND n.is_deleted = 0
        UNION
        SELECT d.locale_id FROM i18n d
        WHERE  d.[key] = c.description_key AND d.space_id = @SpaceId AND d.is_deleted = 0
        UNION
        SELECT x.locale_id FROM media_localization x
        WHERE  x.media_id = c.logo_media_id AND x.is_deleted = 0
    ) AS locs
    LEFT JOIN i18n AS iname
           ON iname.[key]      = c.name_key
          AND iname.locale_id  = locs.locale_id
          AND iname.space_id   = @SpaceId
          AND iname.is_deleted = 0
    LEFT JOIN i18n AS idesc
           ON idesc.[key]      = c.description_key
          AND idesc.locale_id  = locs.locale_id
          AND idesc.space_id   = @SpaceId
          AND idesc.is_deleted = 0
    LEFT JOIN media AS m
           ON m.id             = c.logo_media_id
          AND m.space_id       = @SpaceId
          AND m.is_deleted     = 0
    LEFT JOIN media_localization AS ml
           ON ml.media_id      = c.logo_media_id
          AND ml.locale_id     = locs.locale_id
          AND ml.is_deleted    = 0
    LEFT JOIN dbo.content_approval ca
           ON  ca.content_type = 'charity'
          AND  ca.content_id   = c.id
          AND  ca.[status]    != 'withdrawn'
    WHERE c.id         = @CharityId
      AND c.space_id   = @SpaceId
      AND c.is_deleted = 0
    ORDER BY locs.locale_id;
END;
