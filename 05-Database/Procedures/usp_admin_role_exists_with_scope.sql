-- Returns: scalar BIT
CREATE   PROCEDURE [dbo].[usp_admin_role_exists_with_scope]
    @RoleId INT,
    @Scope  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(COUNT(1) AS BIT)
    FROM   [dbo].[role]
    WHERE  [id] = @RoleId AND [scope] = @Scope AND [is_deleted] = 0;
END
