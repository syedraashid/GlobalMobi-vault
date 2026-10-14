-- Atomically transitions a payment_intent from RequiresAction (1) → Processing (2).
-- SET NOCOUNT OFF so @@ROWCOUNT flows back as the result set (Claimed = 1 or 0).
-- Claimed = 1: this caller won the race and owns the capture.
-- Claimed = 0: another concurrent request already transitioned past status 1.
CREATE   PROCEDURE [dbo].[usp_Intent_TryClaimForCapture]
    @IntentId UNIQUEIDENTIFIER,
    @ModBy    VARCHAR(36)
AS
BEGIN
    SET NOCOUNT OFF;
    UPDATE payment_intent
    SET    status_id     = 2,
           modified_time = SYSUTCDATETIME(),
           modified_by   = @ModBy
    WHERE  id        = @IntentId
      AND  status_id = 1;
    SELECT @@ROWCOUNT AS Claimed;
END
