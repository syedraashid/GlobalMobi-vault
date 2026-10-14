------------------------------------------------------------------------
-- 3) usp_Item_SoftDelete — deleting the item entity itself
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_Item_SoftDelete]
    @ItemId     INT,
    @SpaceId    INT,
    @ModifiedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ItemTypeId    INT;
    DECLARE @MerchThumbId  BIGINT;
    DECLARE @BadgeMediaId  BIGINT;
    DECLARE @AvatarThumbId BIGINT;

    SELECT
        @ItemTypeId    = i.item_type_id,
        @MerchThumbId  = m.thumbnail_media_id,
        @BadgeMediaId  = b.media_id,
        @AvatarThumbId = a.thumbnail_media_id
    FROM dbo.item i
    LEFT JOIN dbo.merchandise m ON m.id = i.id
    LEFT JOIN dbo.badge       b ON b.id = i.id
    LEFT JOIN dbo.avatar      a ON a.id = i.id
    WHERE i.id = @ItemId AND i.space_id = @SpaceId AND i.is_deleted = 0;

    IF @ItemTypeId IS NULL
    BEGIN
        RAISERROR('Item not found in this space.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.shop_items     SET is_deleted = 1 WHERE item_id = @ItemId;
    UPDATE dbo.item_discounts SET is_deleted = 1 WHERE item_id = @ItemId;
    UPDATE dbo.item_prices    SET is_deleted = 1 WHERE item_id = @ItemId;

    UPDATE dbo.free_trial_items SET is_deleted = 1, modified_time = SYSUTCDATETIME(), modified_by = @ModifiedBy
    WHERE item_id = @ItemId AND is_deleted = 0;

    -- Same scoping as sp_FreeTrialItem_Delete, including the same
    -- package-coverage exception (see the comment there for why).
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

    IF @ItemTypeId = 1
        UPDATE dbo.merchandise SET is_deleted = 1, modified_by = @ModifiedBy WHERE id = @ItemId;
    ELSE IF @ItemTypeId = 2
        UPDATE dbo.ticket      SET is_deleted = 1, modified_by = @ModifiedBy WHERE id = @ItemId;
    ELSE IF @ItemTypeId = 3
        UPDATE dbo.badge       SET is_deleted = 1, modified_by = @ModifiedBy WHERE id = @ItemId;
    ELSE IF @ItemTypeId = 6
        UPDATE dbo.avatar      SET is_deleted = 1, modified_by = @ModifiedBy WHERE id = @ItemId;

    IF @MerchThumbId IS NOT NULL
    BEGIN
        UPDATE dbo.media_localization SET is_deleted = 1 WHERE media_id = @MerchThumbId;
        UPDATE dbo.media SET is_deleted = 1, modified_by = @ModifiedBy
        WHERE id = @MerchThumbId AND space_id = @SpaceId;
    END;

    IF @BadgeMediaId IS NOT NULL
    BEGIN
        UPDATE dbo.media_localization SET is_deleted = 1 WHERE media_id = @BadgeMediaId;
        UPDATE dbo.media SET is_deleted = 1, modified_by = @ModifiedBy
        WHERE id = @BadgeMediaId AND space_id = @SpaceId;
    END;

    IF @AvatarThumbId IS NOT NULL
    BEGIN
        UPDATE dbo.media_localization SET is_deleted = 1 WHERE media_id = @AvatarThumbId;
        UPDATE dbo.media SET is_deleted = 1, modified_by = @ModifiedBy
        WHERE id = @AvatarThumbId AND space_id = @SpaceId;
    END;

    UPDATE dbo.item SET is_deleted = 1, modified_by = @ModifiedBy
    WHERE id = @ItemId AND space_id = @SpaceId;
END
