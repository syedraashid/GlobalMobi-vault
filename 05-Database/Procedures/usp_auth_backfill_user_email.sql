-- =============================================================================
-- REVIEW-PASS FIX — backfill email on the Unity fast-path sign-in.
-- Unity rows created before this session's fixes never captured email at all
-- (Phase 3 only saves it going forward, on new signups). Without this, such a
-- user can sign into Unity indefinitely and their row's email stays NULL
-- forever, meaning a later CMS invite for that same email can never find them
-- via usp_admin_get_cms_user_by_email (NULL never equals @Email, regardless of
-- is_deleted) and silently creates a second, disconnected account instead of
-- linking. Calling this unconditionally on every fast-path sign-in makes the
-- gap self-healing: the first login after this fix ships captures the email,
-- and every CMS invite after that resolves correctly. Guarded explicitly
-- (existence check, not try/catch) so it never risks the sign-in itself —
-- if some other active row already legitimately owns this email, skip.
-- =============================================================================
CREATE   PROCEDURE [dbo].[usp_auth_backfill_user_email]
    @UserId     UNIQUEIDENTIFIER,
    @Email      VARCHAR(256),
    @ModifiedBy VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.[user] WHERE email = @Email AND is_deleted = 0 AND id <> @UserId)
        RETURN;

    UPDATE dbo.[user]
    SET email         = @Email,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE id = @UserId
      AND email IS NULL
      AND is_deleted = 0;
END;
