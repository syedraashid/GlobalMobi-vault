CREATE   PROCEDURE [dbo].[usp_Space_LeaveMultiplayer]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[space]
    SET active_ccu = active_ccu - 1
    WHERE id = @SpaceId AND is_deleted = 0 AND active_ccu > 0;
END
