CREATE   PROCEDURE [dbo].[usp_admin_invite_entity_admin]
    @EntityId   INT,
    @Email      VARCHAR(256),
    @Name       VARCHAR(64)  = NULL,
    @InvitedBy  UNIQUEIDENTIFIER,
    @Token      VARCHAR(64),
    @ExpiresAt  DATETIME2(7),
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExistingUserId    UNIQUEIDENTIFIER;
    DECLARE @ExistingCmsOid    VARCHAR(128);
    DECLARE @EntityAdminRoleId INT;

    SELECT @EntityAdminRoleId = [id] FROM [dbo].[role]
    WHERE  [name] = 'entity_admin' AND [is_deleted] = 0;

    SELECT @ExistingUserId = [id], @ExistingCmsOid = [cms_oid] FROM [dbo].[user]
    WHERE  [email] = @Email AND [is_deleted] = 0;

    IF @ExistingUserId IS NOT NULL AND @ExistingCmsOid IS NOT NULL
    BEGIN
        -- Real CMS user already: promote immediately, no invite email needed.
        UPDATE [dbo].[user]
        SET    [entity_id]      = @EntityId,
               [system_role_id] = @EntityAdminRoleId,
               [modified_time]  = GETUTCDATE(),
               [modified_by]    = @ModifiedBy
        WHERE  [id] = @ExistingUserId;

        SELECT 1 AS ExistingUser;
        RETURN;
    END

    -- Brand new, OR exists but never touched CMS: upsert pending invitation with entity_id.
    IF EXISTS (
        SELECT 1 FROM [dbo].[pending_invitation]
        WHERE  [entity_id]   = @EntityId
          AND  [email]       = @Email
          AND  [accepted_at] IS NULL
          AND  [is_deleted]  = 0
    )
        UPDATE [dbo].[pending_invitation]
        SET    [token]         = @Token,
               [expires_at]    = @ExpiresAt,
               [modified_time] = GETUTCDATE(),
               [modified_by]   = @ModifiedBy
        WHERE  [entity_id]   = @EntityId
          AND  [email]       = @Email
          AND  [accepted_at] IS NULL
          AND  [is_deleted]  = 0;
    ELSE
        INSERT INTO [dbo].[pending_invitation]
            ([entity_id], [space_id], [email], [role_id], [invited_by], [token], [expires_at], [is_deleted], [modified_time], [modified_by])
        VALUES
            (@EntityId, NULL, @Email, @EntityAdminRoleId, @InvitedBy, @Token, @ExpiresAt, 0, GETUTCDATE(), @ModifiedBy);

    SELECT 0 AS ExistingUser;
END;
