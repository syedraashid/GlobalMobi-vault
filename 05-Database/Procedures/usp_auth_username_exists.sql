CREATE   PROCEDURE [dbo].[usp_auth_username_exists]
    @Username varchar(64)
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM dbo.[user]
                WHERE username = @Username
            )
            THEN CAST(1 AS bit)
            ELSE CAST(0 AS bit)
        END AS exists_flag
END
