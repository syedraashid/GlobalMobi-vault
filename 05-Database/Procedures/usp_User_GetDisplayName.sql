-- ============================================================
-- usp_User_GetDisplayName
-- Returns display_name for bill_to_name on invoices.
-- Falls back to user_id (handled in C#) if no display_name is set.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_User_GetDisplayName]
    @UserId VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 display_name
    FROM [user]
    WHERE CAST(id AS VARCHAR(36)) = @UserId;
END
