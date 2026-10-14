-- ============================================================
-- 11. usp_MerchandiseCategory_Insert
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_MerchandiseCategory_Insert]
    @Category   VARCHAR(100),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO merchandise_category (category, is_deleted, modified_by, modified_time)
    VALUES (@Category, 0, @ModifiedBy, GETUTCDATE());
    SELECT SCOPE_IDENTITY() AS Id;
END
