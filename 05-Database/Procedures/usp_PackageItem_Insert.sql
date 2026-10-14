-- ------------------------------------------------------------
-- 9) usp_PackageItem_Insert / usp_PackageItem_Delete / usp_PackageItem_SelectByPackage
--    Insert enforces: no self-reference (impossible anyway, package_id
--    and item_id reference different tables), no duplicate (unique
--    constraint backstops this, but a friendly error is raised first).
--    Nesting (adding a package as a member) is structurally impossible —
--    item_id only FKs to item.id, and packages have no item row.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_PackageItem_Insert]
    @PackageId  INT,
    @ItemId     INT,
    @Quantity   INT = 1,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.package WHERE id = @PackageId AND is_deleted = 0)
    BEGIN
        RAISERROR('Package not found.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.item WHERE id = @ItemId AND is_deleted = 0)
    BEGIN
        RAISERROR('Item not found.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM dbo.package_item WHERE package_id = @PackageId AND item_id = @ItemId AND is_deleted = 0)
    BEGIN
        RAISERROR('This item is already in the package.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.package_item (package_id, item_id, quantity, status, is_deleted, modified_time, modified_by)
    VALUES (@PackageId, @ItemId, @Quantity, 'draft', 0, SYSUTCDATETIME(), @ModifiedBy);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS package_item_id;
END
