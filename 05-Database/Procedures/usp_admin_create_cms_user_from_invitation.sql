-- 1. Verbatim from dev (2026-08-12) — no changes.
CREATE   PROCEDURE [dbo].[usp_admin_create_cms_user_from_invitation]
    @Oid   VARCHAR(128),
    @Email VARCHAR(256),
    @Name  VARCHAR(64) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @UserId      UNIQUEIDENTIFIER;
        DECLARE @LoginTypeId INT;
        DECLARE @UserTypeId  INT;

        SELECT @LoginTypeId = [id] FROM [dbo].[login_type] WHERE [type] = 'microsoft';
        SELECT @UserTypeId  = [id] FROM [dbo].[user_type]  WHERE [type] = 'registered';

        -- Restore path: user was previously soft-deleted. TOP 1 + ORDER BY is
        -- required here (not just a plain assignment-SELECT) — since
        -- UQ_user_email is now filtered to active rows only, multiple
        -- soft-deleted rows CAN share the same email (delete/re-create/delete
        -- cycles), and without a defined order this would non-deterministically
        -- restore an arbitrary historical row instead of the most recent one.
        SELECT TOP 1 @UserId = [id] FROM [dbo].[user]
        WHERE  [email] = @Email AND [is_deleted] = 1
        ORDER BY [modified_time] DESC;

        IF @UserId IS NOT NULL
        BEGIN
            UPDATE [dbo].[user]
            SET [is_deleted]    = 0,
                [cms_oid]       = @Oid,
                [display_name]  = ISNULL(@Name, [display_name]),
                [login_type_id] = @LoginTypeId,
                [user_type_id]  = @UserTypeId,
                [modified_time] = GETUTCDATE(),
                [modified_by]   = 'system'
            WHERE [id] = @UserId;
        END
        ELSE
        BEGIN
            SET @UserId = NEWID();
            INSERT INTO [dbo].[user]
                ([id],[username],[display_name],[email],[cms_oid],
                 [user_type_id],[login_type_id],[is_deleted],[modified_time],[modified_by])
            VALUES
                (@UserId,@Email,ISNULL(@Name,@Email),@Email,@Oid,
                 @UserTypeId,@LoginTypeId,0,GETUTCDATE(),'system');
        END

        EXEC dbo.usp_admin_apply_pending_invitation
            @UserId = @UserId, @Email = @Email, @ModifiedBy = 'system';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT
        u.id           AS UserId,
        u.display_name AS Name,
        u.email        AS Email,
        sr.[name]      AS SystemRole,
        u.cms_oid      AS CmsOid,
        u.entity_id    AS EntityId
    FROM [dbo].[user] u
    LEFT JOIN [dbo].[role] sr ON sr.[id] = u.[system_role_id] AND sr.[is_deleted] = 0
    WHERE u.[id] = @UserId;
END;
