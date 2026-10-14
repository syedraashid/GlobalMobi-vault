CREATE   PROCEDURE [dbo].[usp_auth_create_session]
    @SessionId uniqueidentifier,
    @UserId uniqueidentifier,
    @DeviceId varchar(255),
    @StatusId int,
    @PlatformTypeId int = NULL,
    @GeolocationId uniqueidentifier = NULL,
    @SpaceId int,
    @IpAddress varchar(45) = NULL,
    @ExpirationTime datetime2 = NULL,
    @ModifiedBy varchar(36)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.user_session_management
        (
            id,
            user_id,
            geolocation_id,
            platform_type_id,
            space_id,
            ip_address,
            status_id,
            start_time,
            last_active_time,
            end_time,
            expiration_time,
            modified_by,
            device_id
        )
        VALUES
        (
            @SessionId,
            @UserId,
            @GeolocationId,
            @PlatformTypeId,
            @SpaceId,
            @IpAddress,
            @StatusId,
            SYSUTCDATETIME(),
            SYSUTCDATETIME(),
            NULL,
            @ExpirationTime,
            @ModifiedBy,
            @DeviceId
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
