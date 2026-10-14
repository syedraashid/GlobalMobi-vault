CREATE   PROCEDURE [dbo].[usp_auth_get_session_status_id_by_status]
    @Status varchar(64)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1 id
    FROM dbo.session_status
    WHERE status = @Status;
END
