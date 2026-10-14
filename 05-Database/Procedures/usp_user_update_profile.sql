CREATE   PROCEDURE [dbo].[usp_user_update_profile]
    @UserId uniqueidentifier,
    @Username varchar(64),
    @DisplayName varchar(64),
    @AvatarId varchar(255) = NULL,
    @ModifiedBy varchar(36)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.[user]
        SET
            username = @Username,
            display_name = @DisplayName,
            avatar_id = @AvatarId,
            modified_time = SYSUTCDATETIME(),
            modified_by = @ModifiedBy
        WHERE id = @UserId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
