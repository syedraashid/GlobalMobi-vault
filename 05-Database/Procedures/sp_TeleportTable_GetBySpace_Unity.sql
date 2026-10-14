CREATE   PROCEDURE [dbo].[sp_TeleportTable_GetBySpace_Unity]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    SELECT
        t.id           AS table_id,
        t.space_id,
        t.is_active,
        t.name_key     AS table_name_key,
        i.locale_id    AS table_locale_id,
        i.[value]      AS table_localized_value,

        b.id           AS button_id,
        b.name_key     AS button_name_key,
        b.is_active    AS button_is_active,
        b.map_spot_id,

        ms.x           AS map_spot_x,
        ms.y           AS map_spot_y,
        ms.z           AS map_spot_z,

        tbp.id         AS position_id,

        bi.locale_id   AS button_locale_id,
        bi.[value]     AS button_localized_value

    FROM   [dbo].[teleport_table] t
    LEFT JOIN [dbo].[i18n]                     i   ON  i.[key]      = t.name_key
                                                   AND i.space_id   = t.space_id
                                                   AND i.is_deleted = 0
    LEFT JOIN [dbo].[teleport_table_button]    b   ON  b.teleport_table_id = t.id
                                                   AND b.[status]           = 'approved'
                                                   AND b.is_active          = 1
    LEFT JOIN [dbo].[map_spot]                 ms  ON  ms.id = b.map_spot_id
    LEFT JOIN [dbo].[teleport_button_position] tbp ON  tbp.id = b.position_id
    LEFT JOIN [dbo].[i18n]                     bi  ON  bi.[key]     = b.name_key
                                                   AND bi.space_id  = t.space_id
                                                   AND bi.is_deleted = 0
    WHERE  t.space_id   = @SpaceId
      AND  t.is_deleted = 0
    ORDER BY b.id, bi.locale_id;
END;
