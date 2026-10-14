-- Kept for backward compatibility — now delegates to usp_admin_add_role_to_member.
-- "Update role" in the old single-role model = add role in the multi-role model.
CREATE   PROCEDURE [dbo].[usp_admin_update_member_role]
    @SpaceId    INT,
    @UserId     UNIQUEIDENTIFIER,
    @RoleId     INT,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC [dbo].[usp_admin_add_role_to_member]
        @SpaceId    = @SpaceId,
        @UserId     = @UserId,
        @RoleId     = @RoleId,
        @ModifiedBy = @ModifiedBy;
END
