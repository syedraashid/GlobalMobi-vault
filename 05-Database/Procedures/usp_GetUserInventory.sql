CREATE   PROCEDURE [dbo].[usp_GetUserInventory]
    @SpaceId INT,
    @UserId  VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    -- ------------------------------------------------------------
    -- Result set 1: core inventory data. No i18n/media join — exactly
    -- one row per owned item / trial grant, never multiplied by locale.
    -- ------------------------------------------------------------
    ;WITH LatestEntitlement AS
    (
        SELECT
            CAST(e.user_id AS VARCHAR(36))        AS user_id,
            TRY_CAST(TRIM(ol.item_ref_id) AS INT) AS item_id,
            es.status                              AS entitlement_status,
            CAST(o.id AS VARCHAR(36))              AS order_id,
            ol.unit_amount                         AS paid_unit_amount_minor,
            o.currency_id,
            ROW_NUMBER() OVER (
                PARTITION BY e.user_id, ol.item_ref_id
                ORDER BY e.granted_datetime DESC
            ) AS rn
        FROM dbo.entitlement        e
        JOIN dbo.entitlement_status es ON es.id = e.status_id
        JOIN dbo.order_line_item    ol ON ol.id = e.order_line_item_id
        JOIN dbo.orders             o  ON o.id  = ol.order_id
        WHERE e.user_id     = @UserId   -- scope the window spool to one user
          AND e.is_deleted  = 0
          AND ol.is_deleted = 0
          AND e.status_id  <> 3
          AND TRY_CAST(TRIM(ol.item_ref_id) AS INT) IS NOT NULL
    )
    SELECT
        CAST(ui.id AS VARCHAR(36))  AS inventory_entry_id,
        ui.item_id,
        ui.quantity                 AS total_quantity,
        ui.modified_time            AS acquired_at,

        ui.item_type_id,
        it.[type]                   AS item_type_name,
        COALESCE(i.is_available, pk.is_available) AS is_available,

        m.merchandise_type_id,
        mt.[type]                   AS merchandise_type_name,
        mt.position                 AS merchandise_position,
        mt.interaction              AS merchandise_interaction,
        m.merchandise_category_id,
        mc.category                 AS merchandise_category_name,
        m.asset_url,

        t.event_id,
        t.ticket_type_id,
        tt.[type]                   AS ticket_type_name,
        t.seat,
        t.section,
        t.valid_from,
        t.valid_to,
        t.is_transferable,

        a.asset_url                 AS avatar_asset_url,

        pk.base_cost                AS package_base_cost,

        le.entitlement_status,
        le.order_id,
        le.paid_unit_amount_minor,
        le.currency_id,

        pg.is_prize_grant,
        CAST(0 AS BIT)              AS trial_is_grant,
        CAST(NULL AS DATE)          AS trial_expires_at

    FROM dbo.user_inventory ui

    CROSS APPLY (
        SELECT CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.game_announcement_winner gw
            JOIN dbo.orders o            ON o.id       = gw.granted_order_id
            JOIN dbo.order_line_item ol  ON ol.order_id = o.id
            WHERE gw.user_id  = ui.user_id
              AND gw.is_deleted = 0
              AND TRY_CAST(TRIM(ol.item_ref_id) AS INT) = ui.item_id
        ) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_prize_grant
    ) pg

    LEFT JOIN dbo.item i  ON i.id           = ui.item_id
                         AND ui.item_type_id <> 7
                         AND i.space_id      = @SpaceId
                         AND i.is_deleted    = 0

    LEFT JOIN dbo.package pk ON pk.id          = ui.item_id
                            AND ui.item_type_id = 7
                            AND pk.space_id     = @SpaceId
                            AND pk.is_deleted   = 0

    JOIN dbo.item_type it ON it.id = ui.item_type_id

    LEFT JOIN dbo.merchandise m  ON m.id           = i.id
                             AND i.item_type_id = 1
                             AND m.is_deleted   = 0

    LEFT JOIN dbo.merchandise_type     mt ON mt.id = m.merchandise_type_id
    LEFT JOIN dbo.merchandise_category mc ON mc.id = m.merchandise_category_id

    LEFT JOIN dbo.ticket t  ON t.id           = i.id
                       AND i.item_type_id  = 2
                       AND t.is_deleted    = 0

    LEFT JOIN dbo.ticket_type tt ON tt.id = t.ticket_type_id

    LEFT JOIN dbo.avatar a  ON a.id           = i.id
                       AND i.item_type_id  = 6
                       AND a.is_deleted    = 0

    LEFT JOIN (
        SELECT * FROM LatestEntitlement WHERE rn = 1
    ) le ON le.user_id = @UserId AND le.item_id = ui.item_id

    WHERE ui.user_id   = @UserId
      AND (i.id IS NOT NULL OR pk.id IS NOT NULL)
      -- same row-existence rule the old inner JOIN to i18n enforced
      -- (an item with no name row in the space never appeared at all)
      AND EXISTS (
          SELECT 1 FROM dbo.i18n n
          WHERE n.[key] = COALESCE(CAST(i.name_key AS UNIQUEIDENTIFIER), pk.name_key)
            AND n.space_id = @SpaceId AND n.is_deleted = 0
      )

    UNION ALL

    SELECT
        CAST(g.id AS VARCHAR(36))   AS inventory_entry_id,
        COALESCE(g.item_id, g.package_id) AS item_id,
        g.quantity                  AS total_quantity,
        g.claimed_at                AS acquired_at,

        COALESCE(i.item_type_id, 7) AS item_type_id,
        it.[type]                   AS item_type_name,
        COALESCE(i.is_available, pk.is_available) AS is_available,

        m.merchandise_type_id,
        mt.[type]                   AS merchandise_type_name,
        mt.position                 AS merchandise_position,
        mt.interaction              AS merchandise_interaction,
        m.merchandise_category_id,
        mc.category                 AS merchandise_category_name,
        m.asset_url,

        t.event_id,
        t.ticket_type_id,
        tt.[type]                   AS ticket_type_name,
        t.seat,
        t.section,
        t.valid_from,
        t.valid_to,
        t.is_transferable,

        a.asset_url                 AS avatar_asset_url,

        pk.base_cost                AS package_base_cost,

        CAST(NULL AS VARCHAR(64))   AS entitlement_status,
        CAST(NULL AS VARCHAR(36))   AS order_id,
        CAST(NULL AS BIGINT)        AS paid_unit_amount_minor,
        CAST(NULL AS INT)           AS currency_id,

        CAST(0 AS BIT)              AS is_prize_grant,
        CAST(1 AS BIT)              AS trial_is_grant,
        fts.end_at                  AS trial_expires_at

    FROM dbo.user_free_trial_grant_item g

    JOIN dbo.free_trial_settings fts
        ON fts.space_id = g.space_id
       AND fts.is_deleted = 0
       AND fts.[status]   = 'approved'
       AND fts.is_enabled = 1
       AND CAST(GETUTCDATE() AS DATE) BETWEEN fts.start_at AND fts.end_at

    LEFT JOIN dbo.item i  ON i.id           = g.item_id
                         AND i.space_id      = @SpaceId
                         AND i.is_deleted    = 0

    LEFT JOIN dbo.package pk ON pk.id          = g.package_id
                            AND g.item_id IS NULL
                            AND pk.space_id     = @SpaceId
                            AND pk.is_deleted   = 0

    JOIN dbo.item_type it ON it.id = COALESCE(i.item_type_id, 7)

    LEFT JOIN dbo.merchandise m  ON m.id           = i.id
                             AND i.item_type_id = 1
                             AND m.is_deleted   = 0

    LEFT JOIN dbo.merchandise_type     mt ON mt.id = m.merchandise_type_id
    LEFT JOIN dbo.merchandise_category mc ON mc.id = m.merchandise_category_id

    LEFT JOIN dbo.ticket t  ON t.id           = i.id
                       AND i.item_type_id  = 2
                       AND t.is_deleted    = 0

    LEFT JOIN dbo.ticket_type tt ON tt.id = t.ticket_type_id

    LEFT JOIN dbo.avatar a  ON a.id           = i.id
                       AND i.item_type_id  = 6
                       AND a.is_deleted    = 0

    WHERE g.user_id  = @UserId
      AND g.space_id = @SpaceId
      AND g.is_deleted = 0
      AND EXISTS (
          SELECT 1 FROM dbo.i18n n
          WHERE n.[key] = COALESCE(CAST(i.name_key AS UNIQUEIDENTIFIER), pk.name_key)
            AND n.space_id = @SpaceId AND n.is_deleted = 0
      )

    ORDER BY acquired_at DESC;

    -- ------------------------------------------------------------
    -- Result set 2: per-locale text + media links. Narrow — only
    -- re-joins item/package/merchandise/badge/avatar (to resolve their
    -- media ids) plus i18n + media_localization. No merchandise_type/
    -- ticket/entitlement/prize-grant joins here at all.
    -- ------------------------------------------------------------
    SELECT
        CAST(ui.id AS VARCHAR(36))  AS inventory_entry_id,
        n.locale_id,
        n.value                     AS name_value,
        d.value                     AS description_value,
        tm.media_link               AS thumbnail_url,
        bm.media_link               AS badge_media_url,
        am.media_link               AS avatar_thumb_media_link,
        pkm.media_link              AS package_thumb_media_link

    FROM dbo.user_inventory ui

    LEFT JOIN dbo.item i  ON i.id           = ui.item_id
                         AND ui.item_type_id <> 7
                         AND i.space_id      = @SpaceId
                         AND i.is_deleted    = 0

    LEFT JOIN dbo.package pk ON pk.id          = ui.item_id
                            AND ui.item_type_id = 7
                            AND pk.space_id     = @SpaceId
                            AND pk.is_deleted   = 0

    JOIN dbo.i18n n  ON n.[key]      = COALESCE(CAST(i.name_key AS UNIQUEIDENTIFIER), pk.name_key)
                AND n.space_id   = @SpaceId
                AND n.is_deleted = 0

    LEFT JOIN dbo.i18n d ON d.[key]      = COALESCE(CAST(i.description_key AS UNIQUEIDENTIFIER), pk.description_key)
                    AND d.locale_id  = n.locale_id
                    AND d.space_id   = @SpaceId
                    AND d.is_deleted = 0

    LEFT JOIN dbo.merchandise m  ON m.id           = i.id
                             AND i.item_type_id = 1
                             AND m.is_deleted   = 0

    LEFT JOIN dbo.media_localization tm ON tm.media_id  = m.thumbnail_media_id
                                   AND tm.locale_id = n.locale_id

    LEFT JOIN dbo.badge b  ON b.id           = i.id
                      AND i.item_type_id  = 3
                      AND b.is_deleted    = 0

    LEFT JOIN dbo.media_localization bm ON bm.media_id  = b.media_id
                                   AND bm.locale_id = n.locale_id

    LEFT JOIN dbo.avatar a  ON a.id           = i.id
                       AND i.item_type_id  = 6
                       AND a.is_deleted    = 0

    LEFT JOIN dbo.media_localization am ON am.media_id  = a.thumbnail_media_id
                                   AND am.locale_id = n.locale_id

    LEFT JOIN dbo.media_localization pkm ON pkm.media_id  = pk.thumbnail_media_id
                                    AND pkm.locale_id = n.locale_id

    WHERE ui.user_id   = @UserId
      AND (i.id IS NOT NULL OR pk.id IS NOT NULL)

    UNION ALL

    SELECT
        CAST(g.id AS VARCHAR(36))   AS inventory_entry_id,
        n.locale_id,
        n.value                     AS name_value,
        d.value                     AS description_value,
        tm.media_link               AS thumbnail_url,
        bm.media_link               AS badge_media_url,
        am.media_link               AS avatar_thumb_media_link,
        pkm.media_link              AS package_thumb_media_link

    FROM dbo.user_free_trial_grant_item g

    JOIN dbo.free_trial_settings fts
        ON fts.space_id = g.space_id
       AND fts.is_deleted = 0
       AND fts.[status]   = 'approved'
       AND fts.is_enabled = 1
       AND CAST(GETUTCDATE() AS DATE) BETWEEN fts.start_at AND fts.end_at

    LEFT JOIN dbo.item i  ON i.id           = g.item_id
                         AND i.space_id      = @SpaceId
                         AND i.is_deleted    = 0

    LEFT JOIN dbo.package pk ON pk.id          = g.package_id
                            AND g.item_id IS NULL
                            AND pk.space_id     = @SpaceId
                            AND pk.is_deleted   = 0

    JOIN dbo.i18n n  ON n.[key]      = COALESCE(CAST(i.name_key AS UNIQUEIDENTIFIER), pk.name_key)
                AND n.space_id   = @SpaceId
                AND n.is_deleted = 0

    LEFT JOIN dbo.i18n d ON d.[key]      = COALESCE(CAST(i.description_key AS UNIQUEIDENTIFIER), pk.description_key)
                    AND d.locale_id  = n.locale_id
                    AND d.space_id   = @SpaceId
                    AND d.is_deleted = 0

    LEFT JOIN dbo.merchandise m  ON m.id           = i.id
                             AND i.item_type_id = 1
                             AND m.is_deleted   = 0

    LEFT JOIN dbo.media_localization tm ON tm.media_id  = m.thumbnail_media_id
                                   AND tm.locale_id = n.locale_id

    LEFT JOIN dbo.badge b  ON b.id           = i.id
                      AND i.item_type_id  = 3
                      AND b.is_deleted    = 0

    LEFT JOIN dbo.media_localization bm ON bm.media_id  = b.media_id
                                   AND bm.locale_id = n.locale_id

    LEFT JOIN dbo.avatar a  ON a.id           = i.id
                       AND i.item_type_id  = 6
                       AND a.is_deleted    = 0

    LEFT JOIN dbo.media_localization am ON am.media_id  = a.thumbnail_media_id
                                   AND am.locale_id = n.locale_id

    LEFT JOIN dbo.media_localization pkm ON pkm.media_id  = pk.thumbnail_media_id
                                    AND pkm.locale_id = n.locale_id

    WHERE g.user_id  = @UserId
      AND g.space_id = @SpaceId
      AND g.is_deleted = 0

    ORDER BY inventory_entry_id, locale_id;
END
