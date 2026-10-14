CREATE   PROCEDURE [dbo].[usp_auth_link_microsoft_identity]
    @UserId     uniqueidentifier,
    @Oid        varchar(128),
    @Tid        varchar(128),
    @ModifiedBy varchar(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MicrosoftLoginTypeId INT;
    SELECT @MicrosoftLoginTypeId = [id] FROM dbo.login_type WHERE [type] = 'microsoft';

    UPDATE dbo.[user]
    SET oid            = @Oid,
        tid            = @Tid,
        login_type_id  = @MicrosoftLoginTypeId,
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
