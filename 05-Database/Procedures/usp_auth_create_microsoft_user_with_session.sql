CREATE   PROCEDURE [dbo].[usp_auth_create_microsoft_user_with_session]
    @UserId uniqueidentifier,
    @Username varchar(64),
    @DisplayName varchar(64),
    @Oid varchar(128),
    @Tid varchar(128),
    @Email varchar(256) = NULL,
    @AvatarId varchar(255) = NULL,
    @UserTypeId int,
    @LoginTypeId int,
    @SessionId uniqueidentifier,
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

        INSERT INTO dbo.[user]
        (
            id,
            platform_type_id,
            username,
            display_name,
            user_type_id,
            user_age_range_id,
            oid,
            tid,
            email,
            avatar_id,
            login_type_id,
            modified_by
        )
        VALUES
        (
            @UserId,
            @PlatformTypeId,
            @Username,
            @DisplayName,
            @UserTypeId,
            NULL,
            @Oid,
            @Tid,
            @Email,
            @AvatarId,
            @LoginTypeId,
            @ModifiedBy
        );

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

        SELECT
            u.id AS UserId,
            u.username AS Username,
            u.display_name AS DisplayName,
            u.oid AS Oid,
            u.tid AS Tid,
            u.google_sub AS GoogleSub,
            ISNULL(u.avatar_id, '') AS AvatarId,
            lt.type AS LoginType,
            ut.[type] AS UserType
        FROM dbo.[user] u
        INNER JOIN dbo.login_type lt
            ON lt.id = u.login_type_id
        INNER JOIN dbo.user_type ut
            ON ut.id = u.user_type_id
        WHERE u.id = @UserId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
