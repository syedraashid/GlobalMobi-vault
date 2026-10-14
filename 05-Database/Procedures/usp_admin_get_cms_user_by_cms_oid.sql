-- =============================================================================
-- SECTION 7 — Stored Procedures: CMS Auth
-- =============================================================================

-- Returns: UserId, Name, Email, SystemRole, CmsOid, EntityId
CREATE   PROCEDURE [dbo].[usp_admin_get_cms_user_by_cms_oid]
    @CmsOid VARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.[id]           AS UserId,
        u.[display_name] AS Name,
        u.[email]        AS Email,
        sr.[name]        AS SystemRole,
        u.[cms_oid]      AS CmsOid,
        u.[entity_id]    AS EntityId
    FROM  [dbo].[user] u
    LEFT JOIN [dbo].[role] sr ON sr.[id] = u.[system_role_id] AND sr.[is_deleted] = 0
    WHERE u.[cms_oid] = @CmsOid AND u.[is_deleted] = 0;
END
