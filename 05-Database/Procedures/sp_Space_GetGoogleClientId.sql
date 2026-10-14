------------------------------------------------------------------------
-- 5d) sp_Space_GetGoogleClientId / sp_Space_SetGoogleClientId — per-space
--     OAuth client ID used to validate that space's Google ID tokens.
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_Space_GetGoogleClientId]
    @SpaceId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT google_client_id AS GoogleClientId
    FROM dbo.space
    WHERE id = @SpaceId
      AND is_deleted = 0;
END
