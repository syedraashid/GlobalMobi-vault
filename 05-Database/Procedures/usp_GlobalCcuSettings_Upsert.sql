CREATE   PROCEDURE [dbo].[usp_GlobalCcuSettings_Upsert]
    @GlobalMaxNormal          INT,
    @GlobalMaxAbsolute        INT,
    @MaxPlayersPerRoom        INT,
    @InactivityTimeoutSeconds INT,
    @MaxSessionTimerSeconds   INT,
    @ModifiedBy               NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[global_ccu_settings] WHERE id = 1)
    BEGIN
        INSERT INTO [dbo].[global_ccu_settings]
            (id, global_max_normal, global_max_absolute, max_players_per_room,
             inactivity_timeout_seconds, max_session_timer_seconds, modified_by, modified_time)
        VALUES
            (1, @GlobalMaxNormal, @GlobalMaxAbsolute, @MaxPlayersPerRoom,
             @InactivityTimeoutSeconds, @MaxSessionTimerSeconds, @ModifiedBy, SYSUTCDATETIME());
    END
    ELSE
    BEGIN
        UPDATE [dbo].[global_ccu_settings]
        SET global_max_normal          = @GlobalMaxNormal,
            global_max_absolute        = @GlobalMaxAbsolute,
            max_players_per_room       = @MaxPlayersPerRoom,
            inactivity_timeout_seconds = @InactivityTimeoutSeconds,
            max_session_timer_seconds  = @MaxSessionTimerSeconds,
            modified_by                = @ModifiedBy,
            modified_time              = SYSUTCDATETIME()
        WHERE id = 1;
    END
END
