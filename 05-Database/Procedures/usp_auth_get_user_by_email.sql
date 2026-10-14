CREATE   PROCEDURE [dbo].[usp_auth_get_user_by_email]
    @Email varchar(256)
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
        ISNULL(lt.type, '') AS LoginType,
        ut.[type] AS UserType
    FROM dbo.[user] u
    LEFT JOIN dbo.login_type lt
        ON lt.id = u.login_type_id
    INNER JOIN dbo.user_type ut
        ON ut.id = u.user_type_id
    WHERE u.email = @Email
      AND u.is_deleted = 0;
END
