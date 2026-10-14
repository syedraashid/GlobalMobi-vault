CREATE   PROCEDURE [dbo].[usp_Personality_GetActiveEvents]
    @PersonalityId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.id, en.[value] AS name
    FROM [event] e
    OUTER APPLY (
        SELECT TOP (1) [value]
        FROM i18n
        WHERE [key] = e.localized_name_id AND is_deleted = 0
        ORDER BY locale_id
    ) en
    WHERE e.personality_id = @PersonalityId
      AND e.is_deleted = 0
      AND e.scheduled_end_datetime > SYSUTCDATETIME()
    ORDER BY e.scheduled_end_datetime;
END
