-- ============================================================
-- 8. usp_MerchandiseType_Insert
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_MerchandiseType_Insert]
    @Type        VARCHAR(100),
    @Position    VARCHAR(20)  = 'Top',
    @Interaction VARCHAR(10)  = 'No',
    @ModifiedBy  NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO merchandise_type ([type], position, interaction, is_deleted, modified_by, modified_time)
    VALUES (@Type, @Position, @Interaction, 0, @ModifiedBy, GETUTCDATE());
    SELECT SCOPE_IDENTITY() AS Id;
END
