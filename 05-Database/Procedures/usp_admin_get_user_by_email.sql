-- =============================================================================
-- PHASE 5 — invite-creation three-way check.
-- usp_admin_get_user_by_email now also returns cms_oid (harmless to existing
-- scalar-reading callers, which only ever look at the first column).
-- =============================================================================
CREATE   PROCEDURE [dbo].[usp_admin_get_user_by_email]
    @Email VARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT [id] AS UserId, [cms_oid] AS CmsOid
    FROM   [dbo].[user]
    WHERE  [email] = @Email AND [is_deleted] = 0;
END;
