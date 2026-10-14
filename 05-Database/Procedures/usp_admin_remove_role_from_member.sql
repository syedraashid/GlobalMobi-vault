-- Removes a single role from a space member.
-- If this was their last role the membership record remains (soft-delete via usp_admin_remove_member_from_space).
CREATE   PROCEDURE [dbo].[usp_admin_remove_role_from_member]
    @SpaceId    INT,
    @UserId     UNIQUEIDENTIFIER,
    @RoleId     INT,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MemberId INT;

    SELECT @MemberId = [id]
    FROM   [dbo].[space_member]
    WHERE  [space_id] = @SpaceId AND [user_id] = @UserId AND [is_deleted] = 0;

    IF @MemberId IS NULL RETURN; -- member not found — no-op

    DELETE FROM [dbo].[space_member_role]
    WHERE  [space_member_id] = @MemberId AND [role_id] = @RoleId;

    UPDATE [dbo].[space_member]
    SET    [modified_time] = GETUTCDATE(),
           [modified_by]   = @ModifiedBy
    WHERE  [id] = @MemberId;
END
