-- usp_Order_Snapshot: Phase 9 version — adds net_minor (o.total_net_amount).
-- Older versions computed total from subtotal-discount+tax+fee, which double-counts
-- inclusive tax. net_minor is always the correct charge amount set at order-creation time.
CREATE   PROCEDURE [dbo].[usp_Order_Snapshot]
    @OrderId   UNIQUEIDENTIFIER,
    @SpaceId   INT,
    @TaxTypeId INT = NULL,
    @FeeTypeId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(o.user_id AS NVARCHAR(36)) AS user_id,
        o.space_id,
        o.currency_id,
        o.remarks,
        o.total_net_amount              AS net_minor,
        COALESCE(li.subtotal, 0)        AS subtotal_minor,
        COALESCE(adj.discount, 0)       AS discount_minor,
        COALESCE(adj.tax, 0)            AS tax_minor,
        COALESCE(adj.fee, 0)            AS fee_minor
    FROM orders o
    LEFT JOIN (
        SELECT order_id,
               SUM(unit_amount * quantity) AS subtotal
        FROM order_line_item
        GROUP BY order_id
    ) li ON li.order_id = o.id
    LEFT JOIN (
        SELECT
            order_id,
            SUM(CASE WHEN amount < 0
                     THEN -amount
                     ELSE 0 END) AS discount,
            SUM(CASE WHEN (@TaxTypeId IS NOT NULL AND adjustment_type_id = @TaxTypeId)
                       OR (@TaxTypeId IS NULL     AND code LIKE 'TAX_%')
                     THEN amount
                     ELSE 0 END) AS tax,
            SUM(CASE WHEN (@FeeTypeId IS NOT NULL AND adjustment_type_id = @FeeTypeId)
                       OR (@FeeTypeId IS NULL     AND code LIKE 'FEE_%')
                     THEN amount
                     ELSE 0 END) AS fee
        FROM order_adjustment
        GROUP BY order_id
    ) adj ON adj.order_id = o.id
    WHERE o.id = @OrderId
      AND o.space_id = @SpaceId;
END
