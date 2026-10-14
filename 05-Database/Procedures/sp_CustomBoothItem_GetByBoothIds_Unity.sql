-- ── 4. sp_CustomBoothItem_GetByBoothIds_Unity ───────────────
-- Approved-only variant, no status/approval columns.

CREATE   PROCEDURE [dbo].[sp_CustomBoothItem_GetByBoothIds_Unity]
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
        ci.created_time AS created_at
    FROM   custom_booth_item ci
    JOIN   @Ids b                     ON b.booth_id = ci.booth_id
    JOIN   custom_booth_item_type cit ON cit.id = ci.custom_booth_item_type_id
    JOIN   media cm                   ON cm.id = ci.corresponding_media_id
    WHERE  ci.is_deleted = 0 AND ci.status = 'approved'
      AND  ci.booth_id IN (SELECT booth_id FROM @Ids);

    SELECT ci.id AS custom_booth_item_id, ml.locale_id, ml.media_link
    FROM   custom_booth_item ci
    JOIN   media_localization ml ON ml.media_id = ci.corresponding_media_id AND ml.is_deleted = 0
    WHERE  ci.is_deleted = 0 AND ci.status = 'approved' AND ci.booth_id IN (SELECT booth_id FROM @Ids);

    SELECT ci.id AS custom_booth_item_id, 'name' AS key_type, i.locale_id, i.value
    FROM   custom_booth_item ci
    JOIN   i18n i ON i.[key] = ci.name_key AND i.is_deleted = 0
    WHERE  ci.is_deleted = 0 AND ci.status = 'approved' AND ci.booth_id IN (SELECT booth_id FROM @Ids)
    UNION ALL
    SELECT ci.id, 'description', i.locale_id, i.value
    FROM   custom_booth_item ci
    JOIN   i18n i ON i.[key] = ci.description_key AND i.is_deleted = 0
    WHERE  ci.is_deleted = 0 AND ci.status = 'approved' AND ci.booth_id IN (SELECT booth_id FROM @Ids)
      AND  ci.description_key IS NOT NULL;
END
