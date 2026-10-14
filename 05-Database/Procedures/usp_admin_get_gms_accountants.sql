-- =============================================================================
-- 5. usp_admin_get_gms_accountants
-- Returns all active gms_accountant users (system-wide, no entity scope).
-- AdminSql.cs: GetGmsAccountants
-- =============================================================================
CREATE   PROCEDURE [dbo].[usp_admin_get_gms_accountants]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.[id]            AS UserId,
        u.[display_name]  AS Name,
        u.[email]         AS Email,
        u.[modified_time] AS AssignedAt
    FROM  [dbo].[user] u
    JOIN  [dbo].[role] r
        ON  r.[id]         = u.[system_role_id]
        AND r.[name]       = 'gms_accountant'
        AND r.[is_deleted] = 0
    WHERE u.[is_deleted] = 0
    ORDER BY u.[modified_time] DESC;
END;
