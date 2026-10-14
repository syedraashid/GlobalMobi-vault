CREATE   PROCEDURE [dbo].[usp_admin_remove_member_from_space]
    @SpaceId    INT,
    @UserId     UNIQUEIDENTIFIER,
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MemberId INT = (
        SELECT [id] FROM [dbo].[space_member]
        WHERE [space_id] = @SpaceId AND [user_id] = @UserId AND [is_deleted] = 0
    );

    IF @MemberId IS NOT NULL
    BEGIN
        BEGIN TRANSACTION;

        -- space_member_role has no soft-delete column — delete for real so a
        -- future re-invite to this space doesn't resurrect old role rows.
        DELETE FROM [dbo].[space_member_role]
        WHERE [space_member_id] = @MemberId;

        UPDATE [dbo].[space_member]
        SET    [is_deleted]    = 1,
               [modified_time] = GETUTCDATE(),
               [modified_by]   = @ModifiedBy
        WHERE  [id] = @MemberId;

        COMMIT TRANSACTION;
    END
END
