CREATE   PROCEDURE [dbo].[usp_PackageItem_Delete]
    @PackageId  INT,
    @ItemId     INT,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.package_item
    SET is_deleted = 1, modified_time = SYSUTCDATETIME(), modified_by = @ModifiedBy
    WHERE package_id = @PackageId AND item_id = @ItemId AND is_deleted = 0;
END
