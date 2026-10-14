-- ============================================================
-- usp_TaxCategory_Insert
-- Creates a new tax category for a space.
-- No @IsInclusive parameter — inclusivity is set per-item, not per-category.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_TaxCategory_Insert]
    @SpaceId INT,
    @Name    VARCHAR(100),
    @RatePct DECIMAL(5,2),
    @ModBy   VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO tax_category (space_id, name, rate_pct, is_deleted, modified_time, modified_by)
    VALUES (@SpaceId, @Name, @RatePct, 0, SYSUTCDATETIME(), @ModBy);
    SELECT SCOPE_IDENTITY() AS id;
END
