CREATE   PROCEDURE [dbo].[sp_Space_SetGoogleClientId]
    @SpaceId int,
    @GoogleClientId varchar(255),
    @ModifiedBy varchar(36)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.space
    SET google_client_id = @GoogleClientId,
        modified_time    = SYSUTCDATETIME(),
        modified_by      = @ModifiedBy
    WHERE id = @SpaceId
      AND is_deleted = 0;
END
