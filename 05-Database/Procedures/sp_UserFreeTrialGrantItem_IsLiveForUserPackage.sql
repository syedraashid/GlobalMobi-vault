------------------------------------------------------------------------
-- 3) sp_UserFreeTrialGrantItem_IsLiveForUserPackage — package purchase guard
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_UserFreeTrialGrantItem_IsLiveForUserPackage]
    @SpaceId   INT,
    @UserId    VARCHAR(36),
    @PackageId INT
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
        WHERE g.user_id = @UserId AND g.package_id = @PackageId AND g.space_id = @SpaceId AND g.is_deleted = 0
    ) THEN 1 ELSE 0 END AS is_live;
END
