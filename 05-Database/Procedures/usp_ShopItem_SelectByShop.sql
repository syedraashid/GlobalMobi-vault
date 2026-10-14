-- ============================================================
-- 7. usp_ShopItem_SelectByShop
--    Shop item list — replaces merch_is_top with position +
--    interaction + type name; adds merchandise_category JOIN.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ShopItem_SelectByShop]
    @SpaceId INT,
    @ShopId  INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
      i.id                               AS item_id,
      i.item_type_id,
      i.name_key,
      i.description_key,
      i.is_available,

      COALESCE(si.amount, ip.base_cost)  AS price_minor_units,
      si.stock_quantity,
      si.currency_id,

      d.name_key                         AS discount_name_key,
      d.discount_type_id,
      d.rate_pct                         AS discount_rate_pct,
      d.amount                           AS discount_amount_minor_units,
      d.start_at                         AS discount_start_at,
      d.end_at                           AS discount_end_at,

      m.merchandise_type_id              AS merch_type_id,
      mt.[type]                          AS merchandise_type_name,
      m.merchandise_category_id          AS merch_category_id,
      mc.category                        AS merchandise_category_name,
      m.asset_url                        AS merch_asset_url,
      m.thumbnail_media_id               AS merch_thumb_media_id,
      mt.position                        AS merch_position,
      mt.interaction                     AS merch_interaction,

      t.event_id                         AS ticket_event_id,
      t.ticket_type_id,
      t.seat                             AS ticket_seat,
      t.section                          AS ticket_section,
      t.valid_from                       AS ticket_valid_from,
      t.valid_to                         AS ticket_valid_to,
      t.is_transferable                  AS ticket_is_transferable,

      b.media_id                         AS badge_media_id,

      sl.locale_id,

      tm.media_type_id                   AS merch_thumb_media_type_id,
      tml.media_link                     AS merch_thumb_media_link,
      tm.text_key                        AS merch_thumb_text_key,
      tm.description_key                 AS merch_thumb_desc_key,
      i18n_mt.value                      AS merch_thumb_text_value,
      i18n_md.value                      AS merch_thumb_desc_value,

      bm.media_type_id                   AS badge_media_type_id,
      bml.media_link                     AS badge_media_link,
      bm.text_key                        AS badge_media_text_key,
      bm.description_key                 AS badge_media_desc_key,
      i18n_bt.value                      AS badge_media_text_value,
      i18n_bd.value                      AS badge_media_desc_value

    FROM shop_items si
    JOIN shop s                  ON s.id  = si.shop_id AND s.space_id = @SpaceId
    JOIN item i                  ON i.id  = si.item_id AND i.space_id = @SpaceId AND i.is_deleted = 0
    LEFT JOIN item_prices ip     ON ip.item_id    = i.id
                                AND ip.currency_id = si.currency_id

    LEFT JOIN (
        SELECT *
        FROM (
            SELECT
              idsc.item_id,
              ISNULL(idsc.region_id, 0)      AS region_key,
              d2.id                          AS discount_id,
              d2.name_key,
              d2.discount_type_id,
              d2.rate_pct,
              d2.amount,
              d2.start_at,
              d2.end_at,
              ROW_NUMBER() OVER (
                PARTITION BY idsc.item_id, ISNULL(idsc.region_id, 0)
                ORDER BY d2.end_at DESC, d2.id DESC
              ) AS rn
            FROM item_discounts idsc
            JOIN discounts d2 ON d2.id = idsc.discount_id
            WHERE (d2.start_at IS NULL OR CAST(SYSUTCDATETIME() AS date) >= d2.start_at)
              AND (d2.end_at   IS NULL OR CAST(SYSUTCDATETIME() AS date) <= d2.end_at)
        ) ranked
        WHERE ranked.rn = 1
    ) d ON d.item_id = i.id AND d.region_key = 0

    LEFT JOIN merchandise m            ON m.id = i.id AND m.is_deleted = 0
    LEFT JOIN merchandise_type mt      ON mt.id = m.merchandise_type_id
    LEFT JOIN merchandise_category mc  ON mc.id = m.merchandise_category_id
    LEFT JOIN ticket t                 ON t.id = i.id AND t.is_deleted = 0
    LEFT JOIN badge b                  ON b.id = i.id AND b.is_deleted = 0
    LEFT JOIN supported_languages sl   ON sl.space_id = @SpaceId

    LEFT JOIN media tm                ON tm.id = m.thumbnail_media_id
    LEFT JOIN media_localization tml  ON tml.media_id = tm.id AND tml.locale_id = sl.locale_id
    LEFT JOIN i18n i18n_mt            ON i18n_mt.[key] = tm.text_key        AND i18n_mt.locale_id = sl.locale_id
    LEFT JOIN i18n i18n_md            ON i18n_md.[key] = tm.description_key AND i18n_md.locale_id = sl.locale_id

    LEFT JOIN media bm                ON bm.id = b.media_id
    LEFT JOIN media_localization bml  ON bml.media_id = bm.id AND bml.locale_id = sl.locale_id
    LEFT JOIN i18n i18n_bt            ON i18n_bt.[key] = bm.text_key        AND i18n_bt.locale_id = sl.locale_id
    LEFT JOIN i18n i18n_bd            ON i18n_bd.[key] = bm.description_key AND i18n_bd.locale_id = sl.locale_id

    WHERE si.shop_id    = @ShopId
      AND si.is_deleted = 0;
END
