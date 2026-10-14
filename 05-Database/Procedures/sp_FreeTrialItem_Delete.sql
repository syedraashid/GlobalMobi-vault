------------------------------------------------------------------------
-- 1) sp_FreeTrialItem_Delete — remove an item's individual listing
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_Delete]
    @SpaceId    INT,
    @ItemId     INT,
    @ModifiedBy VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.free_trial_items
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE space_id = @SpaceId AND item_id = @ItemId AND is_deleted = 0;

    -- Revoke only individually-claimed grants for this item — never a
    -- grant the user got through a package, that's a different listing.
    -- EXCEPTION: if the user separately owns a package that still
    -- includes this item as an active member, leave their individual
    -- grant alone — the partial-grant claim model never creates a
    -- second, package-tagged row for an item the user already had, so
    -- this "individual-looking" grant may actually be the only record
    -- of an entitlement that's still backed by an active package.
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
