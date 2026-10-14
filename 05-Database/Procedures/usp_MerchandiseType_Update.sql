-- ============================================================
-- 9. usp_MerchandiseType_Update
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_MerchandiseType_Update]
    @Id          INT,
    @Type        VARCHAR(100)  = NULL,
    @Position    VARCHAR(20)   = NULL,
    @Interaction VARCHAR(10)   = NULL,
    @ModifiedBy  NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE merchandise_type
    SET [type]        = ISNULL(@Type, [type]),
        position      = ISNULL(@Position, position),
        interaction   = ISNULL(@Interaction, interaction),
        modified_by   = @ModifiedBy,
        modified_time = GETUTCDATE()
    WHERE id = @Id AND is_deleted = 0;
END
