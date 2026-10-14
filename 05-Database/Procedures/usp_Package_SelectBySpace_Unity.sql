-- ------------------------------------------------------------
-- 8) usp_Package_SelectBySpace_Unity — approved + available only, no
--    approval columns. Feeds the "packages" content-publish module.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_Package_SelectBySpace_Unity]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- tax_category_id/tax_is_inclusive/tax_category_name/rate_pct added so Unity's catalog
    -- blob can show a tax-aware total the same way ItemUnityView.Tax already does — previously
    -- missing here entirely, so Unity had no way to know a package's real checkout total
    -- beyond the raw (possibly tax-exclusive) base_cost. Bug found 2026-09-17.
    --
    -- p.name_key/p.description_key added 2026-09-17 (later same day) — PackageRepository's
    -- ReadFlatRowsAsync was hardcoding these to NULL for the unity path with the reasoning
    -- "Unity never edits, so it has no use for the raw i18n key". Reversed per request — Unity
    -- gets the key too now, same as Event's own Unity view already does.
    SELECT
        p.id                        AS package_id,
        p.thumbnail_media_id,
        p.base_cost,
        p.currency_id,
        p.tax_category_id,
        p.tax_is_inclusive,
        tc.name                     AS tax_category_name,
        tc.rate_pct,
        p.is_available,
        p.name_key,
        p.description_key,

        sl.locale_id,
        pml.media_link              AS thumbnail_media_link,
        ni.[value]                  AS name_value,
        di.[value]                  AS desc_value

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
    WHERE p.space_id    = @SpaceId
      AND p.is_deleted  = 0
      AND p.[status]    = 'approved'
      AND p.is_available = 1
    ORDER BY p.id, sl.locale_id;
END
