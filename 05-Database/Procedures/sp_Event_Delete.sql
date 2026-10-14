CREATE   PROCEDURE [dbo].[sp_Event_Delete]
    @SpaceId INT,
    @EventId INT,
    @ModifiedBy NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [event]
    SET is_deleted = 1, modified_time = SYSUTCDATETIME(), modified_by = ISNULL(@ModifiedBy, modified_by)
    WHERE id = @EventId AND space_id = @SpaceId AND is_deleted = 0;

    SELECT CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS found;
END;
