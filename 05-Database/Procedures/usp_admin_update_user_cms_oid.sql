-- 2. Verbatim from dev (2026-08-12) — no changes.
CREATE   PROCEDURE [dbo].[usp_admin_update_user_cms_oid]
    @UserId     UNIQUEIDENTIFIER,
    @CmsOid     VARCHAR(128),
    @ModifiedBy VARCHAR(36) = 'system'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MicrosoftLoginTypeId INT;
    DECLARE @Email VARCHAR(256);

    SELECT @MicrosoftLoginTypeId = [id] FROM [dbo].[login_type] WHERE [type] = 'microsoft';

    UPDATE [dbo].[user]
    SET    [cms_oid]       = @CmsOid,
           [login_type_id] = @MicrosoftLoginTypeId,
           [modified_time] = GETUTCDATE(),
           [modified_by]   = @ModifiedBy
    WHERE  [id]         = @UserId
      AND  [is_deleted] = 0;

    SELECT @Email = [email] FROM [dbo].[user] WHERE [id] = @UserId AND [is_deleted] = 0;

    IF @Email IS NOT NULL
        EXEC dbo.usp_admin_apply_pending_invitation
            @UserId = @UserId, @Email = @Email, @ModifiedBy = @ModifiedBy;

    SELECT
        u.[id]           AS UserId,
        u.[display_name] AS Name,
        u.[email]        AS Email,
        sr.[name]        AS SystemRole,
        u.[cms_oid]      AS CmsOid,
        u.[entity_id]    AS EntityId
    FROM  [dbo].[user] u
    LEFT JOIN [dbo].[role] sr ON sr.[id] = u.[system_role_id] AND sr.[is_deleted] = 0
    WHERE u.[id] = @UserId AND u.[is_deleted] = 0;
END;
