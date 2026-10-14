-- ============================================================
-- SECTION 2 — Event  <->  Ticket relationship: access gate, capacity/stock
-- enforcement, and cross-space validation
-- ============================================================

-- Ticket-ownership access-gate proc.
CREATE   PROCEDURE [dbo].[usp_Inventory_HasValidEventTicket]
    @EventId INT,
    @UserId  VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM ticket WHERE event_id = @EventId)
    BEGIN
        SELECT CAST(1 AS BIT) AS HasAccess;  -- no ticket attached at all => free event
        RETURN;
    END;

    SELECT CAST(CASE WHEN EXISTS (
        SELECT 1
        FROM user_inventory ui
        JOIN ticket t ON t.id = ui.item_id
        WHERE t.event_id = @EventId
          AND ui.user_id = @UserId
          AND ui.is_deleted = 0
          AND ui.quantity > 0
          AND t.valid_from <= SYSUTCDATETIME()
          AND t.valid_to   >  SYSUTCDATETIME()
    ) THEN 1 ELSE 0 END AS BIT) AS HasAccess;
END;
