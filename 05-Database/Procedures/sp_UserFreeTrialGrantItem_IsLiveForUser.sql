------------------------------------------------------------------------
-- 2) sp_UserFreeTrialGrantItem_IsLiveForUser — item purchase guard
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_UserFreeTrialGrantItem_IsLiveForUser]
    @SpaceId INT,
    @UserId  VARCHAR(36),
    @ItemId  INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.user_free_trial_grant_item g
        JOIN dbo.free_trial_settings fts
            ON fts.space_id = g.space_id
           AND fts.is_deleted = 0
           AND fts.[status]   = 'approved'
           AND fts.is_enabled = 1
           AND CAST(GETUTCDATE() AS DATE) BETWEEN fts.start_at AND fts.end_at
        WHERE g.user_id = @UserId AND g.item_id = @ItemId AND g.space_id = @SpaceId AND g.is_deleted = 0
    ) THEN 1 ELSE 0 END AS is_live;
END
