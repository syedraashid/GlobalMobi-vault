-- ────────────────────────────────────────────────────────────
-- STEP 2 : SP — get health & safety status for a user
-- ────────────────────────────────────────────────────────────
CREATE   PROCEDURE [dbo].[usp_health_and_safety_get_by_user_id]
    @UserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT health_and_safety_accepted,
           health_and_safety_accepted_at
    FROM   dbo.[user]
    WHERE  id = @UserId;
END
