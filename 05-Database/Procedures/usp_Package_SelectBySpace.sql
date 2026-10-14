CREATE   PROCEDURE [dbo].[usp_Package_SelectBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.id                              AS package_id,
        p.name_key,
        p.description_key,
        p.thumbnail_media_id,
        p.base_cost,
        p.currency_id,
        p.tax_category_id,
        p.tax_is_inclusive,
        tc.name                          AS tax_category_name,
        tc.rate_pct,
        p.is_available,

        sl.locale_id,
        pml.media_link                    AS thumbnail_media_link,
        ni.[value]                        AS name_value,
        di.[value]                        AS desc_value,

        (SELECT COUNT(*) FROM dbo.package_item pi WHERE pi.package_id = p.id AND pi.is_deleted = 0) AS member_count,

        COALESCE(ca.[status], p.status)   AS approval_status,
        ca.id                             AS approval_id,
        ca.[action_type]                  AS approval_action_type,
        ca.[current_snapshot]             AS current_snapshot,
        ca.[proposed_snapshot]            AS proposed_snapshot,
        p.status                          AS content_status

    FROM dbo.package p
    LEFT JOIN dbo.tax_category tc        ON tc.id = p.tax_category_id AND tc.is_deleted = 0
    LEFT JOIN dbo.supported_languages sl ON sl.space_id = p.space_id
    LEFT JOIN dbo.media_localization pml ON pml.media_id  = p.thumbnail_media_id
                                     AND pml.locale_id = sl.locale_id
    LEFT JOIN dbo.i18n ni                ON ni.[key]     = p.name_key
                                     AND ni.space_id  = p.space_id
                                     AND ni.locale_id = sl.locale_id
    LEFT JOIN dbo.i18n di                ON di.[key]     = p.description_key
                                     AND di.space_id  = p.space_id
                                     AND di.locale_id = sl.locale_id
    LEFT JOIN dbo.content_approval ca ON ca.content_type = 'package'
                                      AND ca.content_id   = p.id
                                      AND ca.[status]    != 'withdrawn'
    WHERE p.space_id = @SpaceId AND p.is_deleted = 0
    ORDER BY p.id, sl.locale_id;
END
