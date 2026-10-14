CREATE   PROCEDURE [dbo].[sp_GameAnnouncementWinner_Grant]
    @AnnouncementId  INT,
    @UserId          UNIQUEIDENTIFIER,
    @Rank            INT,
    @Score           BIGINT,
    @GamesPlayed     INT,
    @GrantedOrderId  UNIQUEIDENTIFIER = NULL,
    @GrantedBy       VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.game_announcement_winner
        (announcement_id, user_id, rank, score, games_played, granted_order_id, granted_by)
    VALUES
        (@AnnouncementId, @UserId, @Rank, @Score, @GamesPlayed, @GrantedOrderId, @GrantedBy);

    SELECT id AS Id, announcement_id AS AnnouncementId, user_id AS UserId, rank AS Rank,
           score AS Score, games_played AS GamesPlayed, granted_order_id AS GrantedOrderId,
           granted_time AS GrantedTime, granted_by AS GrantedBy
    FROM dbo.game_announcement_winner
    WHERE announcement_id = @AnnouncementId AND user_id = @UserId;
END
