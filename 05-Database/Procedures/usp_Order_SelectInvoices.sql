-- usp_Order_SelectInvoices: FIXED — returns total_amount as raw BIGINT (no DECIMAL cast).
-- Original returned CAST(total_amount AS DECIMAL(18,4)) which caused InvalidCastException
-- when C# called GetInt64 after the Phase 7 invoice column type change.
CREATE   PROCEDURE [dbo].[usp_Order_SelectInvoices]
    @OrderId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(id AS NVARCHAR(36)) AS id,
        invoice_number,
        status_id,
        currency_id,
        total_amount,            -- BIGINT minor units
        issue_datetime,
        pdf_url
    FROM invoice
    WHERE order_id = @OrderId
    ORDER BY issue_datetime;
END
