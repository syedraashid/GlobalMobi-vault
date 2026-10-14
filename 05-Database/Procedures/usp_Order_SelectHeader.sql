CREATE   PROCEDURE [dbo].[usp_Order_SelectHeader]
    @OrderId UNIQUEIDENTIFIER,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(id AS NVARCHAR(36))                AS id,
        CAST(user_id AS NVARCHAR(36))           AS user_id,
        space_id, transaction_type_id, currency_id, status_id,
        total_gross_amount, total_discount_amount,
        total_tax_amount, total_fee_amount, total_net_amount,
        change_reason,
        CAST(original_order_id AS NVARCHAR(36)) AS original_order_id,
        session_id, gateway_preferred_id, order_datetime, remarks
    FROM orders
    WHERE id = @OrderId
      AND space_id = @SpaceId;
END
