-- ============================================================
-- usp_ShopItem_SelectOne
-- Returns a single shop_items row with subtype detail.
-- Lowercase column aliases to match C# MapRow reader.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_SelectOne]
    @SpaceId    INT,
    @ShopId     INT,
    @ItemId     INT,
    @CurrencyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        i.id                              AS item_id,
        i.item_type_id,
        i.name_key,
        i.description_key,
        i.is_available,

        si.stock_quantity,
        si.amount                         AS override_amount,
        si.currency_id,

        COALESCE(si.amount, ip.base_cost) AS price_minor_units,

        d.name_key                        AS discount_name_key,
        d.discount_type_id,
        d.rate_pct                        AS discount_rate_pct,
        d.amount                          AS discount_amount_minor_units,
        d.start_at                        AS discount_start_at,
        d.end_at                          AS discount_end_at,

        m.merchandise_type_id             AS merch_type_id,
        m.merchandise_category_id         AS merch_category_id,
        m.asset_url                       AS merch_asset_url,
        m.thumbnail_media_id              AS merch_thumbnail_media_id,

        t.event_id                        AS ticket_event_id,
        t.ticket_type_id,
        t.seat                            AS ticket_seat,
        t.section                         AS ticket_section,
        t.valid_from                      AS ticket_valid_from,
        t.valid_to                        AS ticket_valid_to,
        t.is_transferable                 AS ticket_is_transferable,

        b.media_id                        AS badge_media_id

    FROM shop_items si
    JOIN item i               ON i.id = si.item_id AND i.space_id = @SpaceId AND i.is_deleted = 0
    LEFT JOIN item_prices ip  ON ip.item_id = i.id AND ip.currency_id = si.currency_id AND ip.is_deleted = 0
    LEFT JOIN merchandise m   ON m.id = i.id AND m.is_deleted = 0
    LEFT JOIN ticket t        ON t.id = i.id AND t.is_deleted = 0
    LEFT JOIN badge b         ON b.id = i.id AND b.is_deleted = 0
    LEFT JOIN item_discounts idis
           ON idis.item_id = i.id
          AND idis.region_id IS NULL
          AND idis.is_deleted = 0
    LEFT JOIN discounts d
           ON d.id = idis.discount_id
          AND (d.start_at IS NULL OR CAST(SYSUTCDATETIME() AS date) >= d.start_at)
          AND (d.end_at   IS NULL OR CAST(SYSUTCDATETIME() AS date) <= d.end_at)
    WHERE si.shop_id     = @ShopId
      AND i.id           = @ItemId
      AND si.currency_id = @CurrencyId
      AND si.is_deleted  = 0;
END
