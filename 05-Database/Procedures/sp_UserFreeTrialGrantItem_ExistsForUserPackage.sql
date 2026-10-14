-- A9) sp_UserFreeTrialGrantItem_ExistsForUserPackage
CREATE   PROCEDURE [dbo].[sp_UserFreeTrialGrantItem_ExistsForUserPackage]
    @UserId    VARCHAR(36),
    @PackageId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM dbo.user_free_trial_grant_item
    WHERE user_id = @UserId AND package_id = @PackageId AND item_id IS NULL AND is_deleted = 0;
END
