CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_SelectBySpace_Unity]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT item_id
    FROM dbo.free_trial_items
    WHERE space_id = @SpaceId AND is_deleted = 0 AND [status] = 'approved';
END
