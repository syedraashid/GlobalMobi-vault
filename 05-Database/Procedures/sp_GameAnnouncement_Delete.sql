CREATE   PROCEDURE [dbo].[sp_GameAnnouncement_Delete]
    @Id         INT,
    @ModifiedBy VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.game_announcement
    SET is_deleted = 1, modified_by = @ModifiedBy, modified_time = SYSUTCDATETIME()
    WHERE id = @Id;
END
