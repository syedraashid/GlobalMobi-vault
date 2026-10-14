CREATE   PROCEDURE [dbo].[usp_Item_SelectBySpace_Unity]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT
        i.id                        AS item_id,
        i.item_type_id,
        i.name_key,
        i.description_key,
        i.is_available,
        i.tax_category_id,
        i.tax_is_inclusive,
        tc.name                     AS tax_category_name,
        tc.rate_pct                 AS tax_rate_pct,

        ip.base_cost                AS price_minor_units,
        ip.currency_id,

        d.id                        AS discount_id,
        d.discount_type_id,
        d.rate_pct                  AS discount_rate_pct,
        d.amount                    AS discount_amount,
        d.start_at                  AS discount_start_at,
        d.end_at                    AS discount_end_at,

        m.merchandise_type_id,
        mt.[type]                   AS merchandise_type_name,
        m.merchandise_category_id,
        mc.category                 AS merchandise_category_name,
        m.asset_url,
        m.thumbnail_media_id,
        mt.position                 AS merch_position,
        mt.interaction              AS merch_interaction,

        t.event_id,
        t.ticket_type_id,
        tt.[type]                   AS ticket_type_name,
        t.seat,
        t.section,
        t.valid_from,
        t.valid_to,
        t.is_transferable,
        t.thumbnail_media_id        AS ticket_thumbnail_media_id,
        si.stock_quantity,
        ev.localized_name_id        AS event_name_key,
        ev.description_id           AS event_desc_key,

        b.media_id                  AS badge_media_id,

        a.asset_url                 AS avatar_asset_url,
        a.thumbnail_media_id        AS avatar_thumbnail_media_id,

        sl.locale_id,
        mtl.media_link              AS merch_thumb_media_link,
        ttl.media_link              AS ticket_thumb_media_link,
        bml.media_link              AS badge_media_link,
        aml.media_link              AS avatar_thumb_media_link,
        ni.[value]                  AS name_value,
        di.[value]                  AS desc_value,
        eni.[value]                 AS event_name_value,
        edi.[value]                 AS event_desc_value

    FROM dbo.item i
    LEFT JOIN dbo.tax_category tc        ON tc.id = i.tax_category_id
    LEFT JOIN dbo.item_prices ip         ON ip.item_id = i.id
                                    AND ip.is_deleted = 0
    LEFT JOIN dbo.item_discounts idis    ON idis.item_id   = i.id
                                    AND idis.is_deleted = 0
                                    AND idis.region_id  IS NULL
    LEFT JOIN dbo.discounts d            ON d.id          = idis.discount_id
                                    AND d.is_deleted   = 0
                                    AND d.[status]    = 'approved'
                                    AND (d.start_at IS NULL OR CAST(SYSUTCDATETIME() AS date) >= d.start_at)
                                    AND (d.end_at   IS NULL OR CAST(SYSUTCDATETIME() AS date) <= d.end_at)
    LEFT JOIN dbo.merchandise m          ON m.id = i.id AND m.is_deleted = 0
    LEFT JOIN dbo.merchandise_type mt    ON mt.id = m.merchandise_type_id
    LEFT JOIN dbo.merchandise_category mc ON mc.id = m.merchandise_category_id
    LEFT JOIN dbo.ticket t               ON t.id = i.id AND t.is_deleted = 0
    LEFT JOIN dbo.ticket_type tt         ON tt.id = t.ticket_type_id
    LEFT JOIN [dbo].[event] ev           ON ev.id = t.event_id
    LEFT JOIN dbo.badge b                ON b.id = i.id AND b.is_deleted = 0
    LEFT JOIN dbo.avatar a               ON a.id = i.id AND a.is_deleted = 0
    LEFT JOIN dbo.shop_items si          ON si.item_id = i.id AND si.is_deleted = 0
    LEFT JOIN dbo.supported_languages sl ON sl.space_id = i.space_id
    LEFT JOIN dbo.media_localization mtl ON mtl.media_id  = m.thumbnail_media_id
                                    AND mtl.locale_id = sl.locale_id
    LEFT JOIN dbo.media_localization ttl ON ttl.media_id  = t.thumbnail_media_id
                                    AND ttl.locale_id = sl.locale_id
    LEFT JOIN dbo.media_localization bml ON bml.media_id  = b.media_id
                                    AND bml.locale_id = sl.locale_id
    LEFT JOIN dbo.media_localization aml ON aml.media_id  = a.thumbnail_media_id
                                    AND aml.locale_id = sl.locale_id
    LEFT JOIN dbo.i18n ni                ON ni.[key]     = i.name_key
                                    AND ni.space_id  = i.space_id
                                    AND ni.locale_id = sl.locale_id
    LEFT JOIN dbo.i18n di                ON di.[key]     = i.description_key
                                    AND di.space_id  = i.space_id
                                    AND di.locale_id = sl.locale_id
    LEFT JOIN dbo.i18n eni               ON eni.[key]    = ev.localized_name_id
                                    AND eni.space_id  = i.space_id
                                    AND eni.locale_id = sl.locale_id
    LEFT JOIN dbo.i18n edi               ON edi.[key]    = ev.description_id
                                    AND edi.space_id  = i.space_id
                                    AND edi.locale_id = sl.locale_id
    WHERE i.space_id    = @SpaceId
      AND i.is_deleted  = 0
      AND i.[status]    = 'approved'
      AND i.is_available = 1
      AND i.is_price_only = 0
    ORDER BY i.id, ip.currency_id, d.id, sl.locale_id;
END
