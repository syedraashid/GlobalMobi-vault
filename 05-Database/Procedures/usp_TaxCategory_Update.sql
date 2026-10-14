-- ============================================================
-- usp_TaxCategory_Update
-- Updates name and rate for an existing tax category.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_TaxCategory_Update]
    @Id      INT,
    @SpaceId INT,
    @Name    VARCHAR(100),
    @RatePct DECIMAL(5,2),
    @ModBy   VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE tax_category
    SET name          = @Name,
        rate_pct      = @RatePct,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModBy
    WHERE id = @Id AND space_id = @SpaceId AND is_deleted = 0;
END
