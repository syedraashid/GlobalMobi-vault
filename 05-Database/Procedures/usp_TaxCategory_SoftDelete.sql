-- ============================================================
-- usp_TaxCategory_SoftDelete
-- Soft-deletes a tax category (is_deleted = 1).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_TaxCategory_SoftDelete]
    @Id      INT,
    @SpaceId INT,
    @ModBy   VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE tax_category
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModBy
    WHERE id = @Id AND space_id = @SpaceId;
END
