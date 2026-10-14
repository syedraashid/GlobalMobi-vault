CREATE   PROCEDURE [dbo].[usp_auth_get_user_type_id_by_type]
    @Type varchar(64)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1 id
    FROM dbo.user_type
    WHERE [type] = @Type;
END
