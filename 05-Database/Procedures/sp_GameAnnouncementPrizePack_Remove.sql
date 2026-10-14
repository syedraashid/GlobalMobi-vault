CREATE   PROCEDURE [dbo].[sp_GameAnnouncementPrizePack_Remove]
    @AnnouncementId INT,
    @ItemId         INT,
    @ModifiedBy     VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.game_announcement_prize_pack
    SET is_deleted = 1, modified_by = @ModifiedBy, modified_time = SYSUTCDATETIME()
    WHERE announcement_id = @AnnouncementId AND item_id = @ItemId;
END
