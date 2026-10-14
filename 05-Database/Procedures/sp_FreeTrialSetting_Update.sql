-- COALESCE-based partial update — only non-NULL params are applied.
CREATE   PROCEDURE [dbo].[sp_FreeTrialSetting_Update]
    @SpaceId       INT,
    @NewStartAt    DATE        = NULL,
    @NewEndAt      DATE        = NULL,
    @NewIsEnabled  BIT         = NULL,
    @ModifiedBy    VARCHAR(200),
    @ForceStatus   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.free_trial_settings
    SET start_at      = COALESCE(@NewStartAt,   start_at),
        end_at        = COALESCE(@NewEndAt,     end_at),
        is_enabled    = COALESCE(@NewIsEnabled, is_enabled),
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy,
        [status]      = ISNULL(@ForceStatus, [status])
    WHERE space_id = @SpaceId AND is_deleted = 0;
END
