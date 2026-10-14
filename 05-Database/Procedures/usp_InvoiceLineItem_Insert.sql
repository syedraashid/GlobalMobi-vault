-- ============================================================
-- usp_InvoiceLineItem_Insert
-- Bulk-inserts invoice line items copied from order_line_item.
-- unit_amount is already BIGINT minor units (Phase 5 fixed the insert).
-- amount = unit_amount × quantity (line total).
-- item_ref_id cast to CHAR(36) matches the Phase 1 schema change.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_InvoiceLineItem_Insert]
    @InvoiceId  UNIQUEIDENTIFIER,
    @OrderId    UNIQUEIDENTIFIER,
    @CurrencyId INT,
    @ModBy      VARCHAR(200) = 'system'
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO invoice_line_item
    (id, invoice_id, item_type_id, item_ref_id, currency_id,
     quantity, unit_amount, amount,
     is_deleted, modified_time, modified_by)
    SELECT
        NEWID(),
        @InvoiceId,
        ol.item_type_id,
        CAST(ol.item_ref_id AS CHAR(36)),
        @CurrencyId,
        ol.quantity,
        ol.unit_amount,
        ol.unit_amount * ol.quantity,
        0, SYSUTCDATETIME(), @ModBy
    FROM order_line_item ol
    WHERE ol.order_id = @OrderId;
END
