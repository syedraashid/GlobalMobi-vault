CREATE   PROCEDURE [dbo].[sp_GameAnnouncementWinner_ListByAnnouncement]
    @AnnouncementId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.id AS Id, w.user_id AS UserId, u.username AS Username, u.email AS Email,
           w.rank AS Rank, w.score AS Score, w.games_played AS GamesPlayed,
           w.granted_order_id AS GrantedOrderId, w.granted_time AS GrantedTime, w.granted_by AS GrantedBy,
           granted.ItemNames AS GrantedItems
    FROM dbo.game_announcement_winner w
    JOIN dbo.[user] u ON u.id = w.user_id
    OUTER APPLY (
        SELECT STRING_AGG(COALESCE(ni.[value], CAST(i.name_key AS VARCHAR(36))), ', ')
            WITHIN GROUP (ORDER BY i.id) AS ItemNames
        FROM dbo.order_line_item oli
        JOIN dbo.item i ON TRY_CAST(oli.item_ref_id AS INT) = i.id
        OUTER APPLY (
            SELECT TOP 1 n.[value] FROM dbo.i18n n
            WHERE n.[key] = i.name_key AND n.space_id = i.space_id
            ORDER BY n.locale_id
        ) ni
        WHERE oli.order_id = w.granted_order_id AND oli.is_deleted = 0
    ) granted
    WHERE w.announcement_id = @AnnouncementId AND w.is_deleted = 0
    ORDER BY w.rank;
END
