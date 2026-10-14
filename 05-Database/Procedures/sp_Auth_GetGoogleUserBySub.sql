------------------------------------------------------------------------
-- 5a) sp_Auth_GetGoogleUserBySub — fast path for a returning Google user.
--     Mirrors usp_auth_get_microsoft_user_by_oid_tid.
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_Auth_GetGoogleUserBySub]
    @GoogleSub varchar(128)
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
    FROM dbo.[user] u
    INNER JOIN dbo.login_type lt
        ON lt.id = u.login_type_id
    INNER JOIN dbo.user_type ut
        ON ut.id = u.user_type_id
    WHERE u.google_sub = @GoogleSub
      AND lt.type = 'google'
      AND u.is_deleted = 0;
END
