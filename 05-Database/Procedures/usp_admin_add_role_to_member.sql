-- Adds a role to an existing space member.
-- Use usp_admin_add_member_to_space for the initial invite.
-- Idempotent — safe to call even if the role is already assigned.
CREATE   PROCEDURE [dbo].[usp_admin_add_role_to_member]
    @SpaceId    INT,
    @UserId     UNIQUEIDENTIFIER,
    @RoleId     INT,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MemberId INT;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[role] WHERE [id] = @RoleId AND [is_deleted] = 0)
    BEGIN
        RAISERROR('Invalid role_id %d', 16, 1, @RoleId);
        RETURN;
    END

    SELECT @MemberId = [id]
    FROM   [dbo].[space_member]
    WHERE  [space_id] = @SpaceId AND [user_id] = @UserId AND [is_deleted] = 0;

    IF @MemberId IS NULL
    BEGIN
        RAISERROR('User is not a member of space %d', 16, 1, @SpaceId);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[space_member_role] WHERE [space_member_id] = @MemberId AND [role_id] = @RoleId)
        INSERT INTO [dbo].[space_member_role] ([space_member_id], [role_id])
        VALUES (@MemberId, @RoleId);

    UPDATE [dbo].[space_member]
    SET    [modified_time] = GETUTCDATE(),
           [modified_by]   = @ModifiedBy
    WHERE  [id] = @MemberId;
END
