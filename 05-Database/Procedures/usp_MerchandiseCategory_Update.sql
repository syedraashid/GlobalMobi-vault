-- ============================================================
-- 12. usp_MerchandiseCategory_Update
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_MerchandiseCategory_Update]
    @Id         INT,
    @Category   VARCHAR(100),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE merchandise_category
    SET category      = @Category,
        modified_by   = @ModifiedBy,
        modified_time = GETUTCDATE()
    WHERE id = @Id AND is_deleted = 0;
END
