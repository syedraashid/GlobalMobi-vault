CREATE   PROCEDURE [dbo].[sp_FreeTrialSetting_SelectBySpace_Unity]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, space_id, start_at, end_at, is_enabled
    FROM dbo.free_trial_settings
    WHERE space_id = @SpaceId AND is_deleted = 0 AND [status] = 'approved';
END
