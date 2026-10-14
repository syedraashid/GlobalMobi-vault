CREATE   PROCEDURE [dbo].[usp_auth_end_session]
    @SessionId  uniqueidentifier,
    @UserId     uniqueidentifier,
    @ModifiedBy varchar(36)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @StatusId INT;

        SELECT @StatusId = status_id
        FROM dbo.user_session_management
        WHERE id = @SessionId AND user_id = @UserId AND is_deleted = 0;

        IF @StatusId IS NULL
            THROW 50404, 'Session not found.', 1;

        IF @StatusId = 3
            THROW 50409, 'Session has already been ended.', 1;

        UPDATE dbo.user_session_management
        SET
            status_id     = 3,
            end_time      = SYSUTCDATETIME(),
            modified_by   = @ModifiedBy,
            modified_time = SYSUTCDATETIME()
        WHERE id = @SessionId;

        COMMIT TRANSACTION;

        SELECT
            CAST(@SessionId AS varchar(36)) AS SessionId,
            end_time                        AS EndedAt
        FROM dbo.user_session_management
        WHERE id = @SessionId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
