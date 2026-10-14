-- ============================================================
-- 13. usp_MerchandiseCategory_SoftDelete
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_MerchandiseCategory_SoftDelete]
    @Id         INT,
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE merchandise_category
    SET is_deleted    = 1,
        modified_by   = @ModifiedBy,
        modified_time = GETUTCDATE()
    WHERE id = @Id;
END
