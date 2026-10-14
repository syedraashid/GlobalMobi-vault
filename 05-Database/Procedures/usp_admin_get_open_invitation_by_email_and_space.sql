-- Returns the invitee display name for a single open, unexpired pending_invitation
-- in the given space for the given email. Returns no rows if none exists.
-- Used by the invite endpoint to block duplicate invitations.
CREATE   PROCEDURE [dbo].[usp_admin_get_open_invitation_by_email_and_space]
    @Email   VARCHAR(256),
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        ISNULL(pi.[name], pi.[email]) AS InviteeName
    FROM  [dbo].[pending_invitation] pi
    WHERE pi.[email]       = @Email
      AND pi.[space_id]    = @SpaceId
      AND pi.[accepted_at] IS NULL
      AND pi.[is_deleted]  = 0
      AND pi.[expires_at]  > GETUTCDATE()
    ORDER BY pi.[id] DESC;
END
