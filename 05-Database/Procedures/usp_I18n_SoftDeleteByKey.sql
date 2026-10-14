-- ============================================================
-- usp_I18n_SoftDeleteByKey
-- Soft-deletes all i18n rows for a given key + space.
-- Called before usp_I18n_Upsert in the discount update flow.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_I18n_SoftDeleteByKey]
    @Key        UNIQUEIDENTIFIER,
    @SpaceId    INT,
    @ModifiedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE i18n
    SET is_deleted    = 1,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModifiedBy
    WHERE [key]      = @Key
      AND space_id   = @SpaceId
      AND is_deleted = 0;
END
