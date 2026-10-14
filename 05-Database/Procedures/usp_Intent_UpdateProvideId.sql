-- SET NOCOUNT ON omitted intentionally — ExecuteNonQueryAsync must see rows affected.
CREATE   PROCEDURE [dbo].[usp_Intent_UpdateProvideId]
    @IntentId UNIQUEIDENTIFIER,
    @ProvId   VARCHAR(128),
    @ModBy    VARCHAR(36)
AS
BEGIN
    UPDATE payment_intent
    SET provider_intent_id = @ProvId,
        modified_time      = SYSUTCDATETIME(),
        modified_by        = @ModBy
    WHERE id        = @IntentId
      AND status_id = 1;
END
