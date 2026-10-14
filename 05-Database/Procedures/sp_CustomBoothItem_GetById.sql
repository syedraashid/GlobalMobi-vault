-- ── 5. sp_CustomBoothItem_GetById ───────────────────────────

CREATE   PROCEDURE [dbo].[sp_CustomBoothItem_GetById]
    @SpaceId INT,
    @Id      INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ci.id, ci.booth_id, ci.custom_booth_item_type_id, cit.type_key,
        ci.corresponding_media_id, cm.media_type_id AS corr_media_type_id,
        ci.name_key, ci.description_key,
        ci.start_datetime, ci.end_datetime,
        ci.status, ci.created_time AS created_at
    FROM   custom_booth_item ci
    JOIN   booth b                    ON b.id = ci.booth_id AND b.space_id = @SpaceId
    JOIN   custom_booth_item_type cit ON cit.id = ci.custom_booth_item_type_id
    JOIN   media cm                   ON cm.id = ci.corresponding_media_id
    WHERE  ci.id = @Id AND ci.is_deleted = 0;

    SELECT ml.locale_id, ml.media_link
    FROM   custom_booth_item ci
    JOIN   media_localization ml ON ml.media_id = ci.corresponding_media_id AND ml.is_deleted = 0
    WHERE  ci.id = @Id AND ci.is_deleted = 0;

    SELECT 'name' AS key_type, i.locale_id, i.value
    FROM   custom_booth_item ci
    JOIN   i18n i ON i.[key] = ci.name_key AND i.is_deleted = 0
    WHERE  ci.id = @Id AND ci.is_deleted = 0
    UNION ALL
    SELECT 'description', i.locale_id, i.value
    FROM   custom_booth_item ci
    JOIN   i18n i ON i.[key] = ci.description_key AND i.is_deleted = 0
    WHERE  ci.id = @Id AND ci.is_deleted = 0 AND ci.description_key IS NOT NULL;
END
