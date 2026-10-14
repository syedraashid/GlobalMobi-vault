-- ============================================================
-- usp_PaymentAuditLog_Insert
-- Appends one audit row for any field-level change in the payment flow.
-- Called after every status transition, capture, and refund.
-- All parameters are optional except SourceTable, SourceRowId, ColumnName, ChangedBy.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_PaymentAuditLog_Insert]
    @OrderId      CHAR(36)     = NULL,
    @SourceTable  VARCHAR(100),
    @SourceRowId  CHAR(36),
    @ColumnName   VARCHAR(100),
    @OldValue     VARCHAR(500) = NULL,
    @NewValue     VARCHAR(500) = NULL,
    @ChangeReason VARCHAR(500) = NULL,
    @ChangedBy    VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO payment_audit_log
        (id, order_id, source_table, source_row_id, column_name,
         old_value, new_value, change_reason, changed_by, modified_time)
    VALUES
        (NEWID(), @OrderId, @SourceTable, @SourceRowId, @ColumnName,
         @OldValue, @NewValue, @ChangeReason, @ChangedBy, SYSUTCDATETIME());
END
