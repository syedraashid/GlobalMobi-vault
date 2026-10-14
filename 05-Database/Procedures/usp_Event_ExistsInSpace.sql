CREATE   PROCEDURE [dbo].[usp_Event_ExistsInSpace]
    @EventId INT,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM [event]
    WHERE id = @EventId
      AND space_id  = @SpaceId
      AND is_deleted = 0;
END
