-- usp_Order_InsertAdjustment: Phase 5 version — adds @TaxCategoryId to snapshot
-- which tax category triggered each TAX_ adjustment row.
CREATE   PROCEDURE [dbo].[usp_Order_InsertAdjustment]
    @Id            UNIQUEIDENTIFIER,
    @OrderId       UNIQUEIDENTIFIER,
    @OrderLineId   UNIQUEIDENTIFIER = NULL,
    @ItemTypeId    SMALLINT,
    @Code          VARCHAR(64)   = NULL,
    @Amount        BIGINT,
    @DescKey       VARCHAR(255)  = NULL,
    @Meta          NVARCHAR(MAX) = NULL,
    @TaxCategoryId INT           = NULL,
    @ModBy         VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO order_adjustment
    (id, order_id, order_line_item_id, adjustment_type_id, code, amount,
     description_key, metadata, tax_category_id, is_deleted, modified_time, modified_by)
    VALUES
    (@Id, @OrderId, @OrderLineId, @ItemTypeId, @Code, @Amount,
     @DescKey, @Meta, @TaxCategoryId, 0, SYSUTCDATETIME(), @ModBy);
END
