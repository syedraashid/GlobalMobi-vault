------------------------------------------------------------------------
-- 5) Stored procedures
------------------------------------------------------------------------

CREATE   PROCEDURE [dbo].[sp_FreeTrialSetting_ExistsForSpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM dbo.free_trial_settings
    WHERE space_id = @SpaceId AND is_deleted = 0;
END
