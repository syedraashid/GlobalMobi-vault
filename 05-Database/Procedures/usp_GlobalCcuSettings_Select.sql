CREATE   PROCEDURE [dbo].[usp_GlobalCcuSettings_Select]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        global_max_normal,
        global_max_absolute,
        max_players_per_room,
        inactivity_timeout_seconds,
        max_session_timer_seconds
    FROM [dbo].[global_ccu_settings]
    WHERE id = 1;
END
