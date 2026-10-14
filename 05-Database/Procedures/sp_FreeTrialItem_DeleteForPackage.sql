------------------------------------------------------------------------
-- 2) sp_FreeTrialItem_DeleteForPackage — remove a package's listing
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_DeleteForPackage]
    @SpaceId    INT,
    @PackageId  INT,
    @ModifiedBy VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.free_trial_items
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE space_id = @SpaceId AND package_id = @PackageId AND is_deleted = 0;

    -- Revoke the package grant itself AND every member-item grant that
    -- came through this package (both share package_id = @PackageId) —
    -- never a separate individual claim of the same member item.
    UPDATE dbo.user_free_trial_grant_item
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE space_id = @SpaceId AND package_id = @PackageId AND is_deleted = 0;
END
