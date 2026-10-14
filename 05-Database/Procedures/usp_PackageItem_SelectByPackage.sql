CREATE   PROCEDURE [dbo].[usp_PackageItem_SelectByPackage]
    @PackageId     INT,
    @SpaceId       INT,
    @ApprovedOnly  BIT = 0    -- 0 = CMS admin view (all statuses); 1 = Unity/purchase (approved only)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        pi.id                          AS package_item_id,
        pi.item_id,
        pi.quantity,
        pi.status                      AS membership_status,

        i.item_type_id,
        it.[type]                      AS item_type_name,

        ip.base_cost                   AS price_minor_units,
        ip.currency_id,

        sl.locale_id,
        ni.[value]                     AS name_value,

        m.asset_url                    AS merch_asset_url,
        mtl.media_link                 AS merch_thumb_media_link,
        ttl.media_link                 AS ticket_thumb_media_link,
        btl.media_link                 AS badge_media_link,
        atl.media_link                 AS avatar_thumb_media_link

    FROM dbo.package_item pi
    JOIN dbo.item      i  ON i.id = pi.item_id AND i.space_id = @SpaceId AND i.is_deleted = 0
    JOIN dbo.item_type it ON it.id = i.item_type_id
    LEFT JOIN dbo.item_prices ip ON ip.item_id = i.id AND ip.is_deleted = 0
    LEFT JOIN dbo.supported_languages sl ON sl.space_id = i.space_id
    LEFT JOIN dbo.i18n ni ON ni.[key] = i.name_key AND ni.space_id = i.space_id AND ni.locale_id = sl.locale_id
    LEFT JOIN dbo.merchandise m ON m.id = i.id AND i.item_type_id = 1 AND m.is_deleted = 0
    LEFT JOIN dbo.ticket      t ON t.id = i.id AND i.item_type_id = 2 AND t.is_deleted = 0
    LEFT JOIN dbo.badge       b ON b.id = i.id AND i.item_type_id = 3 AND b.is_deleted = 0
    LEFT JOIN dbo.avatar      a ON a.id = i.id AND i.item_type_id = 6 AND a.is_deleted = 0
    LEFT JOIN dbo.media_localization mtl ON mtl.media_id = m.thumbnail_media_id AND mtl.locale_id = sl.locale_id
    LEFT JOIN dbo.media_localization ttl ON ttl.media_id = t.thumbnail_media_id AND ttl.locale_id = sl.locale_id
    LEFT JOIN dbo.media_localization btl ON btl.media_id = b.media_id           AND btl.locale_id = sl.locale_id
    LEFT JOIN dbo.media_localization atl ON atl.media_id = a.thumbnail_media_id AND atl.locale_id = sl.locale_id
    WHERE pi.package_id = @PackageId AND pi.is_deleted = 0
      AND (@ApprovedOnly = 0 OR pi.status = 'approved')
    ORDER BY pi.id, sl.locale_id;
END
