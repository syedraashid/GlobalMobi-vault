CREATE   PROCEDURE [dbo].[usp_Charge_SelectUnassigned]
    @SpaceId          INT,
    @Page             INT,
    @PageSize         INT,
    @DateFrom         DATE         = NULL,
    @DateTo           DATE         = NULL,
    @TransactionType  VARCHAR(20)  = NULL,
    @Search           NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- payment_method_type/Search are additive (parity with the picker looking like
    -- Transaction History) — every other guard here is unaffected by any revision so far:
    -- this proc never referenced payment_deposit at all; "unassigned" has always meant
    -- pc.deposit_id IS NULL. No payment_charge.status_id filter here, deliberately —
    -- usp_Transaction_Select's own "Succeeded" branch doesn't gate on it either (any
    -- non-deleted payment_charge row counts).
    ;WITH Eligible AS (
        SELECT
            CAST(pc.[id] AS NVARCHAR(36)) AS charge_id,
            CAST(pi.[id] AS NVARCHAR(36)) AS payment_intent_id,
            pc.[payer_email]              AS customer,
            COALESCE(u.[display_name], u.[username]) AS customer_name,
            pg.[payment_gateway]          AS gateway,
            pc.[payment_method_type]      AS payment_method,
            pc.[payment_datetime]         AS charge_date,
            cur.[ISO]                     AS currency,
            pc.[currency_id]              AS currency_id,
            pc.[amount_captured]          AS captured_amount,
            pc.[gateway_fee_amount]       AS gateway_fee,
            pc.[exchange_rate]            AS exchange_rate,
            pc.[contract_percentage_applied] AS contract_percentage_applied,
            pc.[merchant_net_amount]      AS merchant_net_amount,
            mcur.[ISO]                    AS merchant_net_currency,
            COUNT(*) OVER()                AS total_count
        FROM   [dbo].[payment_charge] pc
        JOIN   [dbo].[payment_intent] pi  ON pi.[id]  = pc.[payment_intent_id]
        JOIN   [dbo].[orders]         o   ON o.[id]   = pi.[order_id]
        JOIN   [dbo].[payment_gateway] pg ON pg.[id]  = pi.[payment_gateway_id]
        JOIN   [dbo].[currency]       cur ON cur.[id] = pc.[currency_id]
        LEFT JOIN [dbo].[user] u ON u.[id] = o.[user_id]
        LEFT JOIN [dbo].[currency] mcur ON mcur.[id] = pc.[merchant_net_currency_id]
        WHERE  o.[space_id] = @SpaceId
          AND  pc.[deposit_id] IS NULL
          AND  pc.[is_deleted] = 0
          AND  (@DateFrom IS NULL OR CAST(pc.[payment_datetime] AS DATE) >= @DateFrom)
          AND  (@DateTo   IS NULL OR CAST(pc.[payment_datetime] AS DATE) <= @DateTo)
          AND  (@TransactionType IS NULL OR @TransactionType = 'Purchase') -- every eligible row here is a charge, i.e. "Purchase"
          AND  (@Search IS NULL
                OR CAST(pc.[id] AS NVARCHAR(36)) LIKE '%' + @Search + '%'
                OR CAST(pi.[id] AS NVARCHAR(36)) LIKE '%' + @Search + '%'
                OR pc.[payer_email]                       LIKE '%' + @Search + '%'
                OR COALESCE(u.[display_name], u.[username]) LIKE '%' + @Search + '%')
    )
    SELECT charge_id, payment_intent_id, customer, customer_name, gateway, payment_method,
           charge_date, currency, currency_id, captured_amount, gateway_fee, exchange_rate,
           contract_percentage_applied, merchant_net_amount, merchant_net_currency, total_count
    FROM   Eligible
    ORDER BY charge_date DESC
    OFFSET (@Page * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
