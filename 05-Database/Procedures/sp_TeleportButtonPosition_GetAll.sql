-- ── 4. (Intentionally omitted) ───────────────────────────────
-- All buttons start with position_id = NULL (unplaced).
-- Teams assign slots via drag-drop on the Teleport Map UI.
-- Do NOT auto-assign from map_spot_id — that would silently fill
-- all slots on the first loadData() after the SPs are updated.

-- ── 5. Stored procedure: get all 22 global positions ─────────
CREATE   PROCEDURE [dbo].[sp_TeleportButtonPosition_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, created_at, created_by, modified_at, modified_by
    FROM   teleport_button_position
    ORDER  BY id ASC;
END;
