CREATE   PROCEDURE [dbo].[usp_user_get_by_user_id]
    @UserId uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        u.id AS UserId,
        u.username AS Username,
        ISNULL(u.display_name, '') AS DisplayName,
        ISNULL(u.avatar_id, '') AS AvatarId
    FROM dbo.[user] u
    WHERE u.id = @UserId;
END
