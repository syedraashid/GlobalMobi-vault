CREATE   PROCEDURE [dbo].[sp_TeleportButton_GetById]
    @SpaceId  INT,
    @ButtonId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.id           AS button_id,
        b.name_key     AS button_name_key,
        b.is_active    AS button_is_active,
        b.map_spot_id,
        b.icon_key     AS button_icon_key,

        ms.x           AS map_spot_x,
        ms.y           AS map_spot_y,
        ms.z           AS map_spot_z,

        tbp.id         AS position_id,

        bi.locale_id   AS button_locale_id,
        bi.[value]     AS button_localized_value
    FROM   [dbo].[teleport_table_button]      b
    JOIN   [dbo].[teleport_table]             t   ON  t.id = b.teleport_table_id AND t.space_id = @SpaceId
    LEFT JOIN [dbo].[map_spot]                ms  ON  ms.id = b.map_spot_id
    LEFT JOIN [dbo].[teleport_button_position] tbp ON tbp.id = b.position_id
    LEFT JOIN [dbo].[i18n]                    bi  ON  bi.[key]     = b.name_key
                                                  AND bi.space_id  = t.space_id
                                                  AND bi.is_deleted = 0
    WHERE  b.id = @ButtonId
    ORDER BY bi.locale_id;
END
