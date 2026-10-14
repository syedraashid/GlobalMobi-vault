CREATE   PROCEDURE [dbo].[sp_TeleportTable_GetById]
    @SpaceId INT,
    @TableId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.id                   AS table_id,
        t.space_id,
        t.is_active,
        t.name_key             AS table_name_key,
        i.locale_id            AS table_locale_id,
        i.[value]              AS table_localized_value,

        b.id                   AS button_id,
        b.name_key             AS button_name_key,
        b.is_active            AS button_is_active,
        b.map_spot_id,
        b.icon_key             AS button_icon_key,

        ms.x                   AS map_spot_x,
        ms.y                   AS map_spot_y,
        ms.z                   AS map_spot_z,

        tbp.id                 AS position_id,

        bi.locale_id           AS button_locale_id,
        bi.[value]             AS button_localized_value,

        ca.[status]            AS button_approval_status,
        ca.id                  AS button_approval_id,
        TRY_CAST(JSON_VALUE(ca.proposed_data, '$.positionId') AS INT) AS button_proposed_position_id
    FROM   [dbo].[teleport_table]              t
    LEFT JOIN [dbo].[i18n]                     i       ON  i.[key]             = t.name_key
                                                       AND i.space_id          = t.space_id
                                                       AND i.is_deleted        = 0
    LEFT JOIN [dbo].[teleport_table_button]    b       ON  b.teleport_table_id = t.id
    LEFT JOIN [dbo].[map_spot]                 ms      ON  ms.id               = b.map_spot_id
    LEFT JOIN [dbo].[teleport_button_position] tbp     ON  tbp.id              = b.position_id
    LEFT JOIN [dbo].[i18n]                     bi      ON  bi.[key]            = b.name_key
                                                       AND bi.space_id         = t.space_id
                                                       AND bi.is_deleted       = 0
    LEFT JOIN (
        SELECT content_id, MAX(id) AS latest_id
        FROM   [dbo].[content_approval]
        WHERE  content_type = 'teleport_button'
          AND  [status] IN ('pending', 'rejected')
        GROUP BY content_id
    ) ca_latest                                        ON  ca_latest.content_id = b.id
    LEFT JOIN [dbo].[content_approval] ca              ON  ca.id = ca_latest.latest_id
    WHERE  t.space_id = @SpaceId
      AND  t.id       = @TableId
    ORDER BY b.id, bi.locale_id;
END
