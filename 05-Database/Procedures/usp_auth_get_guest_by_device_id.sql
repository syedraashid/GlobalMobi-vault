------------------------------------------------------------------------
-- 6) Existing procedures — add google_sub (aliased GoogleSub) to every
--    result set that feeds AuthRepository.MapAuthUser. No other behavior
--    change; bodies are otherwise identical to the current definitions.
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_auth_get_guest_by_device_id]
    @DeviceId varchar(255)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        u.id AS UserId,
        u.username AS Username,
        u.display_name AS DisplayName,
        u.oid AS Oid,
        u.tid AS Tid,
        u.google_sub AS GoogleSub,
        ISNULL(u.avatar_id, '') AS AvatarId,
        lt.type AS LoginType,
        ut.[type] AS UserType
    FROM dbo.user_session_management usm
    INNER JOIN dbo.[user] u
        ON u.id = usm.user_id
    INNER JOIN dbo.login_type lt
        ON lt.id = u.login_type_id
    INNER JOIN dbo.user_type ut
        ON ut.id = u.user_type_id
    WHERE usm.device_id = @DeviceId
      AND lt.type = 'guest'
      AND u.is_deleted = 0
    ORDER BY usm.modified_time DESC;
END
