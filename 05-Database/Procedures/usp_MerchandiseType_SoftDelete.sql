-- ============================================================
-- 10. usp_MerchandiseType_SoftDelete
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_MerchandiseType_SoftDelete]
    @Id         INT,
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE merchandise_type
    SET is_deleted    = 1,
        modified_by   = @ModifiedBy,
        modified_time = GETUTCDATE()
    WHERE id = @Id;
END
