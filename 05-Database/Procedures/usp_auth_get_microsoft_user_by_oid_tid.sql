CREATE   PROCEDURE [dbo].[usp_auth_get_microsoft_user_by_oid_tid]
    @Oid varchar(128),
    @Tid varchar(128)
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
    WHERE u.oid = @Oid
      AND u.tid = @Tid
      AND lt.type = 'microsoft'
      AND u.is_deleted = 0;
END
