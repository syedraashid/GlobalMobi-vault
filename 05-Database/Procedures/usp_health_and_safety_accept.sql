-- ────────────────────────────────────────────────────────────
-- STEP 3 : SP — accept health & safety (idempotent)
--          Preserves the FIRST acceptance timestamp.
--          Calling it again after acceptance is a no-op on the
--          timestamp (accepted = 1 stays 1, at stays unchanged).
-- ────────────────────────────────────────────────────────────
CREATE   PROCEDURE [dbo].[usp_health_and_safety_accept]
    @UserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.[user]
    SET
        health_and_safety_accepted    = 1,
        health_and_safety_accepted_at = CASE
                                            WHEN health_and_safety_accepted = 0
                                            THEN SYSUTCDATETIME()
                                            ELSE health_and_safety_accepted_at
                                        END
    WHERE id = @UserId;

    SELECT health_and_safety_accepted,
           health_and_safety_accepted_at
    FROM   dbo.[user]
    WHERE  id = @UserId;
END
