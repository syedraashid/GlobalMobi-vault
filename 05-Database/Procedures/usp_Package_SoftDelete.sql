------------------------------------------------------------------------
-- 4) usp_Package_SoftDelete — deleting the package entity itself
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_Package_SoftDelete]
    @PackageId  INT,
    @SpaceId    INT,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ThumbMediaId BIGINT;
    SELECT @ThumbMediaId = thumbnail_media_id
    FROM dbo.package
    WHERE id = @PackageId AND space_id = @SpaceId AND is_deleted = 0;

    IF @ThumbMediaId IS NULL
    BEGIN
        RAISERROR('Package not found in this space.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.package_item SET is_deleted = 1, modified_time = SYSUTCDATETIME(), modified_by = @ModifiedBy
    WHERE package_id = @PackageId;

    UPDATE dbo.free_trial_items SET is_deleted = 1, modified_time = SYSUTCDATETIME(), modified_by = @ModifiedBy
    WHERE package_id = @PackageId AND is_deleted = 0;

    -- Same scoping as sp_FreeTrialItem_DeleteForPackage: the package grant
    -- itself plus every member grant that came through it — never a
    -- separate individual claim of one of its member items.
    UPDATE dbo.user_free_trial_grant_item
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE space_id = @SpaceId AND package_id = @PackageId AND is_deleted = 0;

    UPDATE dbo.media_localization SET is_deleted = 1 WHERE media_id = @ThumbMediaId;
    UPDATE dbo.media SET is_deleted = 1, modified_by = @ModifiedBy
    WHERE id = @ThumbMediaId AND space_id = @SpaceId;

    UPDATE dbo.package SET is_deleted = 1, modified_time = SYSUTCDATETIME(), modified_by = @ModifiedBy
    WHERE id = @PackageId AND space_id = @SpaceId;
END
