------------------------------------------------------------------------
-- 2) usp_user_username_exists_excluding_user  (profile update check)
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_user_username_exists_excluding_user]
    @UserId uniqueidentifier,
    @Username varchar(64)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CASE
        WHEN EXISTS (
            SELECT 1
            FROM dbo.[user]
            WHERE username = @Username
              AND id <> @UserId
              AND is_deleted = 0
        )
        THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS exists_flag;
END;
