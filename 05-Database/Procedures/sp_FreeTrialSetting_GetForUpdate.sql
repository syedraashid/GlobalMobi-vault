-- Lock-read before a PUT — keyed by space_id since a space has exactly one setting.
CREATE   PROCEDURE [dbo].[sp_FreeTrialSetting_GetForUpdate]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, space_id
    FROM dbo.free_trial_settings
    WHERE space_id = @SpaceId AND is_deleted = 0;
END
