-- =============================================================================
-- File   : Data/Scripts/NotInDB/Alter/02_PendingInvitation_SPs_AddName.sql
-- SPs    : usp_admin_get_pending_gms_accountant_invitations
--          usp_admin_get_pending_invitations_by_space
--
-- Change : Add pi.[name] AS Name to SELECT output in both SPs.
--
-- Reason : DB was restored to an older version that predates the Name column
--          addition. C# AdminMemberRepository reads rdr.GetOrdinal("Name")
--          from both SP results, throwing a 500 when the column is absent.
-- =============================================================================


-- ------------------------------------------------------------
-- 1. usp_admin_get_pending_gms_accountant_invitations
--    Adds pi.[name] AS Name to the SELECT list.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_admin_get_pending_gms_accountant_invitations]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pi.[id]                      AS Id,
        pi.[name]                    AS Name,
        pi.[email]                   AS Email,
        pi.[role_id]                 AS RoleId,
        r.[name]                     AS RoleName,
        ISNULL(u.[display_name], '') AS InvitedByName,
        pi.[created_time]            AS CreatedTime,
        pi.[expires_at]              AS ExpiresAt
    FROM  [dbo].[pending_invitation] pi
    JOIN  [dbo].[role] r
        ON  r.[id]         = pi.[role_id]
        AND r.[name]       = 'gms_accountant'
        AND r.[is_deleted] = 0
    LEFT JOIN [dbo].[user] u
        ON  u.[id] = pi.[invited_by]
    WHERE pi.[space_id]    IS NULL
      AND pi.[entity_id]   IS NULL
      AND pi.[accepted_at] IS NULL
      AND pi.[is_deleted]  = 0
      AND pi.[expires_at]  > GETUTCDATE()
    ORDER BY pi.[created_time] DESC;
END
