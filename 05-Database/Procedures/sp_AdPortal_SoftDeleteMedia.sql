CREATE   PROCEDURE [dbo].[sp_AdPortal_SoftDeleteMedia]
    @MediaId    BIGINT,
    @ModifiedBy VARCHAR(36) = 'system'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @now DATETIME2(7) = SYSUTCDATETIME();
    UPDATE media_localization SET is_deleted = 1, modified_by = @ModifiedBy, modified_time = @now WHERE media_id = @MediaId AND is_deleted = 0;
    UPDATE media              SET is_deleted = 1, modified_by = @ModifiedBy, modified_time = @now WHERE id       = @MediaId AND is_deleted = 0;
END
