CREATE   PROCEDURE [dbo].[sp_Item_GetTypeId]
    @ItemId  INT,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT item_type_id FROM dbo.item WHERE id = @ItemId AND space_id = @SpaceId AND is_deleted = 0;
END
