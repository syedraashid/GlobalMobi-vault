------------------------------------------------------------------------
-- 5b) sp_Auth_LinkGoogleIdentity — attach a Google identity onto an
--     existing row (found by email), instead of creating a second,
--     disconnected one. Mirrors usp_auth_link_microsoft_identity.
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_Auth_LinkGoogleIdentity]
    @UserId     uniqueidentifier,
    @GoogleSub  varchar(128),
    @ModifiedBy varchar(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @GoogleLoginTypeId INT;
    SELECT @GoogleLoginTypeId = [id] FROM dbo.login_type WHERE [type] = 'google';

    UPDATE dbo.[user]
    SET google_sub     = @GoogleSub,
        login_type_id  = @GoogleLoginTypeId,
        modified_time  = SYSUTCDATETIME(),
        modified_by    = @ModifiedBy
    WHERE id = @UserId
      AND is_deleted = 0;

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
    WHERE u.id = @UserId
      AND u.is_deleted = 0;
END
