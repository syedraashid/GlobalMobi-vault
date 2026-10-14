-- A3) sp_FreeTrialItem_Insert
CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_Insert]
    @SpaceId    INT,
    @ItemId     INT = NULL,
    @PackageId  INT = NULL,
    @CreatedBy  VARCHAR(200),
    @ModifiedBy VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.free_trial_items
        (space_id, item_id, package_id, is_deleted, created_time, created_by, modified_time, modified_by)
    VALUES
        (@SpaceId, @ItemId, @PackageId, 0, SYSUTCDATETIME(), @CreatedBy, SYSUTCDATETIME(), @ModifiedBy);

    SELECT SCOPE_IDENTITY() AS id;
END
