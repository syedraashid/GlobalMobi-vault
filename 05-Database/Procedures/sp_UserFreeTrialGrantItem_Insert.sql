-- A8) sp_UserFreeTrialGrantItem_Insert
CREATE   PROCEDURE [dbo].[sp_UserFreeTrialGrantItem_Insert]
    @Id         UNIQUEIDENTIFIER,
    @UserId     VARCHAR(36),
    @ItemId     INT = NULL,
    @PackageId  INT = NULL,
    @SpaceId    INT,
    @OrderId    UNIQUEIDENTIFIER,
    @ModifiedBy VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.user_free_trial_grant_item
        (id, user_id, item_id, package_id, space_id, order_id, quantity, claimed_at, is_deleted, modified_time, modified_by)
    VALUES
        (@Id, @UserId, @ItemId, @PackageId, @SpaceId, @OrderId, 1, SYSUTCDATETIME(), 0, SYSUTCDATETIME(), @ModifiedBy);
END
