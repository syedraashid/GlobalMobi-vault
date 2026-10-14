CREATE   PROCEDURE [dbo].[usp_Intent_UpdateStatus]
    @IntentId UNIQUEIDENTIFIER,
    @Status   INT,
    @ModBy    VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE payment_intent
    SET status_id     = @Status,
        modified_time = SYSUTCDATETIME(),
        modified_by   = @ModBy
    WHERE id = @IntentId;
END
