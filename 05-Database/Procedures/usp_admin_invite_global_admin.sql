-- ============================================================
-- SECTION 1: BOOTSTRAP (run once to seed the very first global admin)
--
-- Use Case A when the person already has a [user] row (e.g. they
-- registered via Unity or a previous CMS invite).
--
-- Use Case B when the person has never touched the system at all.
-- After running Case B, send them the CIAM invite link manually.
-- Their first CMS login triggers usp_admin_create_cms_user_from_invitation
-- which reads this pending_invitation and assigns global_admin.
-- ============================================================

-- CASE A: existing user → promote directly
-- Replace 'admin@example.com' with the real email before running.
/*
UPDATE [dbo].[user]
SET    [system_role_id] = (SELECT [id] FROM [dbo].[role] WHERE [name] = 'global_admin' AND [is_deleted] = 0),
       [entity_id]      = NULL,
       [modified_time]  = GETUTCDATE(),
       [modified_by]    = 'bootstrap'
WHERE  [email]      = 'admin@example.com'
  AND  [is_deleted] = 0;
*/

-- CASE B: brand-new user → pending invitation (picked up on first CMS login)
-- Replace email and name before running.
/*
INSERT INTO [dbo].[pending_invitation]
    ([space_id], [entity_id], [email], [name], [role_id],
     [invited_by], [token], [expires_at],
     [is_deleted], [modified_time], [modified_by], [created_by], [created_time])
VALUES
    (NULL, NULL, 'admin@example.com', 'Admin Name',
     (SELECT [id] FROM [dbo].[role] WHERE [name] = 'global_admin' AND [is_deleted] = 0),
     '00000000-0000-0000-0000-000000000001',
     CAST(NEWID() AS VARCHAR(64)),
     DATEADD(DAY, 30, GETUTCDATE()),
     0, GETUTCDATE(), 'bootstrap', 'bootstrap', GETUTCDATE());
*/

-- ============================================================
-- SECTION 2: usp_admin_invite_global_admin
--
-- Three paths:
--
--   A. Existing CMS user (has cms_oid)
--      → promote role immediately, no invitation needed,
--        force-logout triggers JWT refresh on next CMS request.
--        Returns ExistingUser = 1.
--
--   B. Existing Unity-only user (in [user] table, cms_oid IS NULL)
--      → promote role immediately AND create pending_invitation
--        so first CMS login can link their CIAM OID via
--        usp_admin_create_cms_user_from_invitation Path A.
--        Returns ExistingUser = 0 so the service also sends the
--        CIAM invite email (they have no CMS access yet).
--
--   C. Brand-new user (not in [user] table at all)
--      → insert pending_invitation only; role is applied at first
--        CMS login. Returns ExistingUser = 0 (CIAM email sent).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_admin_invite_global_admin]
    @Email      VARCHAR(256),
    @Name       VARCHAR(64)       = NULL,
    @InvitedBy  UNIQUEIDENTIFIER,
    @Token      VARCHAR(64),
    @ExpiresAt  DATETIME2(7),
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExistingUserId    UNIQUEIDENTIFIER;
    DECLARE @ExistingCmsOid    VARCHAR(64);
    DECLARE @GlobalAdminRoleId INT;

    SELECT @GlobalAdminRoleId = [id]
    FROM   [dbo].[role]
    WHERE  [name] = 'global_admin' AND [is_deleted] = 0;

    SELECT @ExistingUserId = [id],
           @ExistingCmsOid = [cms_oid]
    FROM   [dbo].[user]
    WHERE  [email] = @Email AND [is_deleted] = 0;

    -- ── PATH A: existing CMS user (cms_oid already set) ──────────────────────
    -- Role is promoted immediately. No pending_invitation or email needed
    -- because the user already knows how to reach CMS.
    IF @ExistingUserId IS NOT NULL AND @ExistingCmsOid IS NOT NULL
    BEGIN
        UPDATE [dbo].[user]
        SET    [system_role_id] = @GlobalAdminRoleId,
               [entity_id]     = NULL,
               [modified_time] = GETUTCDATE(),
               [modified_by]   = @ModifiedBy
        WHERE  [id] = @ExistingUserId;

        SELECT 1 AS ExistingUser;
        RETURN;
    END

    -- ── PATH B: existing Unity-only user (no cms_oid) ─────────────────────────
    -- Promote role immediately so it is ready the moment they log in.
    -- Also upsert a pending_invitation so that CmsLoginAsync can link their
    -- CIAM OID on first login (GetCmsUserByEmailAsync branch).
    -- Return ExistingUser = 0 so the service sends the CIAM invite email.
    IF @ExistingUserId IS NOT NULL AND @ExistingCmsOid IS NULL
    BEGIN
        UPDATE [dbo].[user]
        SET    [system_role_id] = @GlobalAdminRoleId,
               [entity_id]     = NULL,
               [modified_time] = GETUTCDATE(),
               [modified_by]   = @ModifiedBy
        WHERE  [id] = @ExistingUserId;

        IF EXISTS (
            SELECT 1 FROM [dbo].[pending_invitation]
            WHERE  [email]       = @Email
              AND  [role_id]     = @GlobalAdminRoleId
              AND  [space_id]    IS NULL
              AND  [entity_id]   IS NULL
              AND  [accepted_at] IS NULL
              AND  [is_deleted]  = 0
        )
            UPDATE [dbo].[pending_invitation]
            SET    [token]        = @Token,
                   [expires_at]  = @ExpiresAt,
                   [name]        = ISNULL(@Name, [name]),
                   [modified_time] = GETUTCDATE(),
                   [modified_by] = @ModifiedBy
            WHERE  [email]       = @Email
              AND  [role_id]     = @GlobalAdminRoleId
              AND  [space_id]    IS NULL
              AND  [entity_id]   IS NULL
              AND  [accepted_at] IS NULL
              AND  [is_deleted]  = 0;
        ELSE
            INSERT INTO [dbo].[pending_invitation]
                ([space_id], [entity_id], [email], [name], [role_id],
                 [invited_by], [token], [expires_at],
                 [is_deleted], [modified_time], [modified_by])
            VALUES
                (NULL, NULL, @Email, @Name, @GlobalAdminRoleId,
                 @InvitedBy, @Token, @ExpiresAt,
                 0, GETUTCDATE(), @ModifiedBy);

        SELECT 0 AS ExistingUser;
        RETURN;
    END

    -- ── PATH C: brand-new user (not in [user] table at all) ──────────────────
    -- Role is applied by usp_admin_create_cms_user_from_invitation on first
    -- CMS login. Duplicate check is role-scoped so a gms_accountant invite
    -- for the same email is never overwritten.
    IF EXISTS (
        SELECT 1 FROM [dbo].[pending_invitation]
        WHERE  [email]       = @Email
          AND  [role_id]     = @GlobalAdminRoleId
          AND  [space_id]    IS NULL
          AND  [entity_id]   IS NULL
          AND  [accepted_at] IS NULL
          AND  [is_deleted]  = 0
    )
        UPDATE [dbo].[pending_invitation]
        SET    [token]        = @Token,
               [expires_at]  = @ExpiresAt,
               [name]        = ISNULL(@Name, [name]),
               [modified_time] = GETUTCDATE(),
               [modified_by] = @ModifiedBy
        WHERE  [email]       = @Email
          AND  [role_id]     = @GlobalAdminRoleId
          AND  [space_id]    IS NULL
          AND  [entity_id]   IS NULL
          AND  [accepted_at] IS NULL
          AND  [is_deleted]  = 0;
    ELSE
        INSERT INTO [dbo].[pending_invitation]
            ([space_id], [entity_id], [email], [name], [role_id],
             [invited_by], [token], [expires_at],
             [is_deleted], [modified_time], [modified_by])
        VALUES
            (NULL, NULL, @Email, @Name, @GlobalAdminRoleId,
             @InvitedBy, @Token, @ExpiresAt,
             0, GETUTCDATE(), @ModifiedBy);

    SELECT 0 AS ExistingUser;
END
