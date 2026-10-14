-- =============================================================================
-- SP: sp_TeleportTable_ButtonDuplicateCheck
-- Guard before creating a new teleport button — returns already_exists = 1
-- if the map spot is already used in this table.
-- Used by: TeleportTableSql.ButtonDuplicateCheck
-- =============================================================================
CREATE   PROCEDURE [dbo].[sp_TeleportTable_ButtonDuplicateCheck]
    @TableId   INT,
    @MapSpotId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(1) AS already_exists
    FROM   dbo.teleport_table_button
    WHERE  teleport_table_id = @TableId
      AND  map_spot_id       = @MapSpotId
      AND  is_deleted        = 0;
END;
