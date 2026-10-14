-- ============================================================
-- SP 9: usp_ContentApproval_GetUserDisplayName
-- Returns the display_name for a given user id.
-- Used when building notification/approval messages.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ContentApproval_GetUserDisplayName]
    @UserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 [display_name] AS DisplayName
    FROM [dbo].[user]
    WHERE [id] = @UserId;
END
