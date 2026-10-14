CREATE   PROCEDURE [dbo].[usp_Space_SelectForCcu]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        id,
        ISNULL(display_name, '') AS name,
        is_extra_ccu_enabled
    FROM [dbo].[space]
    WHERE is_deleted = 0
    ORDER BY display_name;
END
