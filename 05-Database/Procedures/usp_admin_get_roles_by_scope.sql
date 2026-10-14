-- =============================================================================
-- SECTION 6 — Stored Procedures: Role Lookups
-- =============================================================================

-- Returns: Id, Name, Description
CREATE   PROCEDURE [dbo].[usp_admin_get_roles_by_scope]
    @Scope VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        [id]          AS Id,
        [name]        AS Name,
        [description] AS Description
    FROM  [dbo].[role]
    WHERE [scope] = @Scope AND [is_deleted] = 0
    ORDER BY [id];
END
