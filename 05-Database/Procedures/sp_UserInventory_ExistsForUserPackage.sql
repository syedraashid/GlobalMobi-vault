-- A11) sp_UserInventory_ExistsForUserPackage
CREATE   PROCEDURE [dbo].[sp_UserInventory_ExistsForUserPackage]
    @UserId    VARCHAR(36),
    @PackageId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM dbo.user_inventory
    WHERE user_id = @UserId AND item_id = @PackageId AND item_type_id = 7
      AND is_deleted = 0 AND quantity > 0;
END
