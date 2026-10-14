CREATE   PROCEDURE [dbo].[sp_GameAnnouncementPrizePack_ListByAnnouncement]
    @AnnouncementId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.id AS Id, p.item_id AS ItemId, COALESCE(ni.[value], CAST(i.name_key AS VARCHAR(36))) AS ItemName
    FROM dbo.game_announcement_prize_pack p
    JOIN dbo.item i ON i.id = p.item_id
    OUTER APPLY (
        SELECT TOP 1 n.[value] FROM dbo.i18n n
        WHERE n.[key] = i.name_key AND n.space_id = i.space_id
        ORDER BY n.locale_id
    ) ni
    WHERE p.announcement_id = @AnnouncementId AND p.is_deleted = 0
    ORDER BY p.item_id;
END
