-- ============================================================
-- SECTION 5 — Event blob-publish support
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_GetSpacesWithEvents]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT space_id
    FROM [event]
    WHERE is_deleted = 0 AND space_id IS NOT NULL;
END
