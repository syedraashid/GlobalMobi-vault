------------------------------------------------------------------------
-- 5) sp_FreeTrialItem_DeleteById — remove a listing by its own row id
-- (the content-approval workflow's path: ContentEditApplier.cs calls this
-- when a FreeTrialItem delete action is approved, instead of (1)/(2)
-- above). Unlike those two, the caller only has the free_trial_items row's
-- own @Id — space_id/item_id/package_id have to be looked up first so the
-- correct revocation branch (item-scoped vs package-scoped) can run.
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_DeleteById]
    @Id         INT,
    @ModifiedBy VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SpaceId INT, @ItemId INT, @PackageId INT;

    SELECT @SpaceId = space_id, @ItemId = item_id, @PackageId = package_id
    FROM dbo.free_trial_items
    WHERE id = @Id AND is_deleted = 0;

    IF @SpaceId IS NULL
        RETURN; -- already removed / doesn't exist — matches the original proc's silent no-op

    UPDATE dbo.free_trial_items
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE id = @Id AND is_deleted = 0;

    IF @ItemId IS NOT NULL
    BEGIN
        -- Same scoping + package-coverage exception as sp_FreeTrialItem_Delete.
        UPDATE g
        SET is_deleted    = 1,
            modified_time = SYSUTCDATETIME(),
            modified_by   = @ModifiedBy
        FROM dbo.user_free_trial_grant_item g
        WHERE g.space_id = @SpaceId AND g.item_id = @ItemId AND g.package_id IS NULL AND g.is_deleted = 0
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.user_free_trial_grant_item pg
              JOIN dbo.package_item pi
                  ON pi.package_id = pg.package_id AND pi.item_id = @ItemId AND pi.is_deleted = 0
              WHERE pg.user_id = g.user_id AND pg.space_id = g.space_id
                AND pg.package_id IS NOT NULL AND pg.item_id IS NULL AND pg.is_deleted = 0
          );
    END
    ELSE IF @PackageId IS NOT NULL
    BEGIN
        -- Same scoping as sp_FreeTrialItem_DeleteForPackage.
        UPDATE dbo.user_free_trial_grant_item
        SET is_deleted    = 1,
            modified_time = SYSUTCDATETIME(),
            modified_by   = @ModifiedBy
        WHERE space_id = @SpaceId AND package_id = @PackageId AND is_deleted = 0;
    END
END
