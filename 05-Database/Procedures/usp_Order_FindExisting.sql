-- ============================================================
-- READ SPs
-- ============================================================

CREATE   PROCEDURE [dbo].[usp_Order_FindExisting]
    @IdemKey VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        CAST(id AS NVARCHAR(36)) AS id,
        total_net_amount,
        space_id
    FROM orders
    WHERE idempotency_key = @IdemKey;
END
