CREATE   PROCEDURE [dbo].[usp_auth_mark_session_active]
    @SessionId  uniqueidentifier,
    @UserId     uniqueidentifier,
    @ModifiedBy varchar(36)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @StatusId       INT;
        DECLARE @ExpirationTime DATETIME2;

        SELECT @StatusId = status_id, @ExpirationTime = expiration_time
        FROM dbo.user_session_management
        WHERE id = @SessionId AND user_id = @UserId AND is_deleted = 0;

        -- Not found
        IF @StatusId IS NULL
            THROW 50404, 'Session not found.', 1;

        -- Already explicitly expired
        IF @StatusId = 3
            THROW 50409, 'Session has expired. Please create a new session.', 1;

        -- Timed out naturally — auto-correct DB then throw
        IF @ExpirationTime IS NOT NULL AND @ExpirationTime < SYSUTCDATETIME()
        BEGIN
            UPDATE dbo.user_session_management
            SET
                status_id     = 3,
                end_time      = SYSUTCDATETIME(),
                modified_by   = @ModifiedBy,
                modified_time = SYSUTCDATETIME()
            WHERE id = @SessionId;

            THROW 50409, 'Session has expired. Please create a new session.', 1;
        END

        -- Valid — mark active
        UPDATE dbo.user_session_management
        SET
            status_id        = 1,
            last_active_time = SYSUTCDATETIME(),
            modified_by      = @ModifiedBy,
            modified_time    = SYSUTCDATETIME()
        WHERE id = @SessionId;

        COMMIT TRANSACTION;

        SELECT
            CAST(@SessionId AS varchar(36)) AS SessionId,
            'active'                        AS Status,
            last_active_time                AS LastActiveAt
        FROM dbo.user_session_management
        WHERE id = @SessionId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
