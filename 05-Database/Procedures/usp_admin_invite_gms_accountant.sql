-- usp_admin_invite_gms_accountant and usp_admin_invite_entity_admin each do
-- their own existing-user check inline (unlike the space-member invite path,
-- which checks in C#). Both previously promoted anyone found by email straight
-- to the role with no CIAM invite email — meaning a Unity-only user promoted
-- this way would have the role in the database but no way to ever authenticate
-- into CIAM to use it. Now only promotes when cms_oid is already set; otherwise
-- falls through to the same pending_invitation path a brand-new user takes, so
-- the CIAM invite email still goes out and the grant applies at first CMS login.
CREATE   PROCEDURE [dbo].[usp_admin_invite_gms_accountant]
    @Email      VARCHAR(256),
    @Name       VARCHAR(64)  = NULL,
    @InvitedBy  UNIQUEIDENTIFIER,
    @Token      VARCHAR(64),
    @ExpiresAt  DATETIME2(7),
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExistingUserId      UNIQUEIDENTIFIER;
    DECLARE @ExistingCmsOid      VARCHAR(128);
    DECLARE @GmsAccountantRoleId INT;

    SELECT @GmsAccountantRoleId = [id] FROM [dbo].[role]
    WHERE  [name] = 'gms_accountant' AND [is_deleted] = 0;

    SELECT @ExistingUserId = [id], @ExistingCmsOid = [cms_oid] FROM [dbo].[user]
    WHERE  [email] = @Email AND [is_deleted] = 0;

    IF @ExistingUserId IS NOT NULL AND @ExistingCmsOid IS NOT NULL
    BEGIN
        -- Real CMS user already: promote immediately, no invite email needed.
        -- Clear entity_id — gms_accountant is not entity-scoped.
        UPDATE [dbo].[user]
        SET    [system_role_id] = @GmsAccountantRoleId,
               [entity_id]     = NULL,
               [modified_time] = GETUTCDATE(),
               [modified_by]   = @ModifiedBy
        WHERE  [id] = @ExistingUserId;

        SELECT 1 AS ExistingUser;
        RETURN;
    END

    -- Brand new, OR exists but never touched CMS (e.g. a Unity-only account):
    -- upsert the pending invitation and let the caller send a CIAM invite email.
    -- The role grant applies at first CMS login via usp_admin_apply_pending_invitation.
    IF EXISTS (
        SELECT 1 FROM [dbo].[pending_invitation]
        WHERE  [email]       = @Email
          AND  [role_id]     = @GmsAccountantRoleId
          AND  [space_id]    IS NULL
          AND  [entity_id]   IS NULL
          AND  [accepted_at] IS NULL
          AND  [is_deleted]  = 0
    )
        UPDATE [dbo].[pending_invitation]
        SET    [token]         = @Token,
               [expires_at]   = @ExpiresAt,
               [name]         = ISNULL(@Name, [name]),
               [modified_time] = GETUTCDATE(),
               [modified_by]  = @ModifiedBy
        WHERE  [email]       = @Email
          AND  [role_id]     = @GmsAccountantRoleId
          AND  [space_id]    IS NULL
          AND  [entity_id]   IS NULL
          AND  [accepted_at] IS NULL
          AND  [is_deleted]  = 0;
    ELSE
        INSERT INTO [dbo].[pending_invitation]
            ([space_id], [entity_id], [email], [role_id], [invited_by],
             [token], [expires_at], [is_deleted], [modified_time], [modified_by], [name])
        VALUES
            (NULL, NULL, @Email, @GmsAccountantRoleId, @InvitedBy,
             @Token, @ExpiresAt, 0, GETUTCDATE(), @ModifiedBy, @Name);

    SELECT 0 AS ExistingUser;
END;
