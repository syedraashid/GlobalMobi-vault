CREATE   PROCEDURE [dbo].[usp_auth_get_login_type_id_by_type]
    @Type varchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1 id
    FROM dbo.login_type
    WHERE type = @Type;
END
