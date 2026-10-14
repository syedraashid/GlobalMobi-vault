CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_GetForUpdate]
    @SpaceId INT,
    @ItemId  INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, space_id, item_id
    FROM dbo.free_trial_items
    WHERE space_id = @SpaceId AND item_id = @ItemId AND is_deleted = 0;
END
