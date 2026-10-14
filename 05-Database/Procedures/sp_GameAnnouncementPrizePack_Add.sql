CREATE   PROCEDURE [dbo].[sp_GameAnnouncementPrizePack_Add]
    @AnnouncementId INT,
    @ItemId         INT,
    @ModifiedBy     VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.game_announcement_prize_pack AS target
    USING (SELECT @AnnouncementId AS announcement_id, @ItemId AS item_id) AS src
    ON  target.announcement_id = src.announcement_id
    AND target.item_id         = src.item_id
    WHEN MATCHED THEN
        UPDATE SET is_deleted = 0, modified_by = @ModifiedBy, modified_time = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (announcement_id, item_id, modified_by)
        VALUES (@AnnouncementId, @ItemId, @ModifiedBy);
END
