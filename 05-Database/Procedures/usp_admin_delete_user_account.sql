-- ============================================================
-- usp_admin_delete_user_account
-- Soft-deletes ALL space memberships for a user, then soft-deletes
-- the user account itself, in a single transaction.
-- Called when admin permanently deletes a user account.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_admin_delete_user_account]
    @UserId    UNIQUEIDENTIFIER,
    @DeletedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION;
    BEGIN TRY

        -- Revoke any open pending invitations so the deleted user cannot
        -- re-activate their account by logging in via an outstanding invite.
        DECLARE @UserEmail VARCHAR(256);
        SELECT @UserEmail = [email] FROM [dbo].[user] WHERE [id] = @UserId;

        IF @UserEmail IS NOT NULL
        BEGIN
            UPDATE [dbo].[pending_invitation]
            SET    [is_deleted]    = 1,
                   [modified_time] = SYSUTCDATETIME(),
                   [modified_by]   = @DeletedBy
            WHERE  [email]       = @UserEmail
              AND  [accepted_at] IS NULL
              AND  [is_deleted]  = 0;
        END

        -- Soft delete all space memberships
        UPDATE dbo.space_member
        SET is_deleted    = 1,
            modified_time = SYSUTCDATETIME(),
            modified_by   = @DeletedBy
        WHERE user_id    = @UserId
          AND is_deleted = 0;

        -- Soft delete the user account
        -- Hard delete not used: user.id is FK in content_approval, orders, etc.
        UPDATE dbo.[user]
        SET is_deleted    = 1,
            modified_time = SYSUTCDATETIME(),
            modified_by   = @DeletedBy
        WHERE id = @UserId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
