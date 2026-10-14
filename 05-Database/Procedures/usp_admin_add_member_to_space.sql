-- Upsert space_member record, then add the given role to space_member_role.
-- If the member already exists (soft-deleted or active), re-activates and adds the role.
-- If the role already exists for this member, the INSERT is skipped (idempotent).
CREATE   PROCEDURE [dbo].[usp_admin_add_member_to_space]
    @SpaceId    INT,
    @UserId     UNIQUEIDENTIFIER,
    @RoleId     INT,
    @InvitedBy  UNIQUEIDENTIFIER,
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

    -- Upsert the membership record
    IF EXISTS (SELECT 1 FROM [dbo].[space_member] WHERE [space_id] = @SpaceId AND [user_id] = @UserId)
        UPDATE [dbo].[space_member]
        SET    [is_deleted]    = 0,
               [modified_time] = GETUTCDATE(),
               [modified_by]   = @ModifiedBy
        WHERE  [space_id] = @SpaceId AND [user_id] = @UserId;
    ELSE
        INSERT INTO [dbo].[space_member]
            ([space_id], [user_id], [invited_by], [joined_at], [is_deleted], [modified_time], [modified_by])
        VALUES
            (@SpaceId, @UserId, @InvitedBy, GETUTCDATE(), 0, GETUTCDATE(), @ModifiedBy);

    SELECT @MemberId = [id] FROM [dbo].[space_member] WHERE [space_id] = @SpaceId AND [user_id] = @UserId;

    -- Add the role if not already assigned
    IF NOT EXISTS (SELECT 1 FROM [dbo].[space_member_role] WHERE [space_member_id] = @MemberId AND [role_id] = @RoleId)
        INSERT INTO [dbo].[space_member_role] ([space_member_id], [role_id])
        VALUES (@MemberId, @RoleId);
END
