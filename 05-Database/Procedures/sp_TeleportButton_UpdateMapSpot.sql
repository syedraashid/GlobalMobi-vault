-- ============================================================
-- sp_TeleportButton_UpdateMapSpot
-- Updates the map_spot_id for a teleport button.
-- Enforces space ownership via the parent teleport_table row.
-- @MapSpotId may be NULL to clear the map spot.
-- ============================================================
CREATE   PROCEDURE [dbo].[sp_TeleportButton_UpdateMapSpot]
    @SpaceId   INT,
    @ButtonId  INT,
    @MapSpotId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE b
    SET    b.map_spot_id = @MapSpotId
    FROM   [dbo].[teleport_table_button] b
    JOIN   [dbo].[teleport_table]        t ON t.id = b.teleport_table_id AND t.space_id = @SpaceId
    WHERE  b.id = @ButtonId;
END
