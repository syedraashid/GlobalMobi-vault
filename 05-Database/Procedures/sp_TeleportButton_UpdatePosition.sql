-- ── 6. Stored procedure: update button position_id ───────────
CREATE   PROCEDURE [dbo].[sp_TeleportButton_UpdatePosition]
    @SpaceId    INT,
    @ButtonId   INT,
    @PositionId INT NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ttb
    SET    ttb.position_id = @PositionId
    FROM   teleport_table_button ttb
    JOIN   teleport_table        tt ON tt.id = ttb.teleport_table_id
    WHERE  ttb.id      = @ButtonId
      AND  tt.space_id = @SpaceId;
END;
