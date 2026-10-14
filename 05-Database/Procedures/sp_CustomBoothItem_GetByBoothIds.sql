CREATE   PROCEDURE [dbo].[sp_CustomBoothItem_GetByBoothIds]
    @SpaceId  INT,
    @BoothIds NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Ids TABLE (booth_id INT PRIMARY KEY);
    INSERT INTO @Ids SELECT value FROM OPENJSON(@BoothIds) WITH (value INT '$');

    SELECT
        ci.id, ci.booth_id, ci.custom_booth_item_type_id, cit.type_key,
        ci.corresponding_media_id, cm.media_type_id AS corr_media_type_id,
        ci.name_key, ci.description_key,
        ci.start_datetime, ci.end_datetime,
        ci.status, ci.created_time AS created_at,
        ca.approval_id, ca.approval_status, ca.approval_action_type,
        ca.current_snapshot, ca.proposed_snapshot
    FROM   custom_booth_item ci
    JOIN   @Ids b                     ON b.booth_id = ci.booth_id
    JOIN   custom_booth_item_type cit ON cit.id = ci.custom_booth_item_type_id
    JOIN   media cm                   ON cm.id = ci.corresponding_media_id
    OUTER APPLY (
        SELECT TOP 1
            c.id                   AS approval_id,
            c.[status]             AS approval_status,
            c.action_type          AS approval_action_type,
            c.[current_snapshot]   AS current_snapshot,
            c.[proposed_snapshot]  AS proposed_snapshot
        FROM  content_approval c WITH (NOLOCK)
        WHERE c.content_type = 'custom_booth_item'
          AND c.content_id   = ci.id
          AND c.[status]    != 'withdrawn'
        ORDER BY c.submitted_at DESC
    ) ca
    WHERE  ci.is_deleted = 0
      AND  ci.booth_id IN (SELECT booth_id FROM @Ids);

    SELECT ci.id AS custom_booth_item_id, ml.locale_id, ml.media_link
    FROM   custom_booth_item ci
    JOIN   media_localization ml ON ml.media_id = ci.corresponding_media_id AND ml.is_deleted = 0
    WHERE  ci.is_deleted = 0 AND ci.booth_id IN (SELECT booth_id FROM @Ids);

    SELECT ci.id AS custom_booth_item_id, 'name' AS key_type, i.locale_id, i.value
    FROM   custom_booth_item ci
    JOIN   i18n i ON i.[key] = ci.name_key AND i.is_deleted = 0
    WHERE  ci.is_deleted = 0 AND ci.booth_id IN (SELECT booth_id FROM @Ids)
    UNION ALL
    SELECT ci.id, 'description', i.locale_id, i.value
    FROM   custom_booth_item ci
    JOIN   i18n i ON i.[key] = ci.description_key AND i.is_deleted = 0
    WHERE  ci.is_deleted = 0 AND ci.booth_id IN (SELECT booth_id FROM @Ids)
      AND  ci.description_key IS NOT NULL;
END
