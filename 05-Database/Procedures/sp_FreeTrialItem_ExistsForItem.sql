------------------------------------------------------------------------
-- 6) Stored procedures — free_trial_items
------------------------------------------------------------------------

CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_ExistsForItem]
    @SpaceId INT,
    @ItemId  INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM dbo.free_trial_items
    WHERE space_id = @SpaceId AND item_id = @ItemId AND is_deleted = 0;
END
