CREATE   PROCEDURE [dbo].[sp_UserInventory_ExistsForUserItem]
    @UserId VARCHAR(36),
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM dbo.user_inventory
    WHERE user_id = @UserId AND item_id = @ItemId AND is_deleted = 0 AND quantity > 0;
END
