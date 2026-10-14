CREATE   PROCEDURE [dbo].[usp_admin_create_pending_invitation]
    @SpaceId    INT,
    @Email      VARCHAR(256),
    @RoleId     INT,
    @InvitedBy  UNIQUEIDENTIFIER,
    @Token      VARCHAR(64),
    @ExpiresAt  DATETIME2(7),
    @ModifiedBy VARCHAR(36),
    @Name       VARCHAR(64) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[role] WHERE [id] = @RoleId AND [is_deleted] = 0)
    BEGIN
        RAISERROR('Invalid role_id %d', 16, 1, @RoleId);
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM [dbo].[pending_invitation]
        WHERE  [space_id]    = @SpaceId
          AND  [email]       = @Email
          AND  [role_id]     = @RoleId
          AND  [accepted_at] IS NULL
          AND  [is_deleted]  = 0
    )
        UPDATE [dbo].[pending_invitation]
        SET    [name]          = @Name,
               [token]         = @Token,
               [expires_at]    = @ExpiresAt,
               [modified_time] = GETUTCDATE(),
               [modified_by]   = @ModifiedBy
        WHERE  [space_id]    = @SpaceId
          AND  [email]       = @Email
          AND  [role_id]     = @RoleId
          AND  [accepted_at] IS NULL
          AND  [is_deleted]  = 0;
    ELSE
        INSERT INTO [dbo].[pending_invitation]
            ([space_id], [email], [name], [role_id], [invited_by], [token], [expires_at],
             [is_deleted], [modified_time], [modified_by], [created_by], [created_time])
        VALUES
            (@SpaceId, @Email, @Name, @RoleId, @InvitedBy, @Token, @ExpiresAt,
             0, GETUTCDATE(), @ModifiedBy, @ModifiedBy, SYSUTCDATETIME());
END
