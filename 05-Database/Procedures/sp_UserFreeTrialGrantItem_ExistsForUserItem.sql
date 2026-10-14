------------------------------------------------------------------------
-- 8) Stored procedures — user_free_trial_grant_item (claim flow)
------------------------------------------------------------------------

CREATE   PROCEDURE [dbo].[sp_UserFreeTrialGrantItem_ExistsForUserItem]
    @UserId VARCHAR(36),
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM dbo.user_free_trial_grant_item
    WHERE user_id = @UserId AND item_id = @ItemId AND is_deleted = 0;
END
