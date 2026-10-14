CREATE   PROCEDURE [dbo].[sp_FreeTrialSetting_Insert]
    @SpaceId    INT,
    @StartAt    DATE,
    @EndAt      DATE,
    @IsEnabled  BIT          = 0,
    @CreatedBy  VARCHAR(200),
    @ModifiedBy VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.free_trial_settings
        (space_id, start_at, end_at, is_enabled, is_deleted, created_time, created_by, modified_time, modified_by)
    VALUES
        (@SpaceId, @StartAt, @EndAt, @IsEnabled, 0, SYSUTCDATETIME(), @CreatedBy, SYSUTCDATETIME(), @ModifiedBy);

    SELECT SCOPE_IDENTITY() AS id;
END
