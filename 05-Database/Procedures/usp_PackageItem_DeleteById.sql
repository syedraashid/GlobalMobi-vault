-- Delete by the package_item row's own id — used by ContentEditApplier.ApplyDeleteAsync,
-- which (like FreeTrialItem's delete case) only has the content_approval content_id, not
-- the (packageId, itemId) pair.
CREATE   PROCEDURE [dbo].[usp_PackageItem_DeleteById]
    @PackageItemId INT,
    @ModifiedBy    VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.package_item
    SET is_deleted = 1, modified_time = SYSUTCDATETIME(), modified_by = @ModifiedBy
    WHERE id = @PackageItemId AND is_deleted = 0;
END
