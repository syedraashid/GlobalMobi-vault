-- ============================================================
-- usp_TaxCategory_SelectById
-- Fetches a single tax category for GET single + Phase 4 validation.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_TaxCategory_SelectById]
    @Id      INT,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, space_id, name, rate_pct, modified_time, modified_by
    FROM tax_category
    WHERE id = @Id AND space_id = @SpaceId AND is_deleted = 0;
END
