CREATE   PROCEDURE [dbo].[usp_Deposit_GetDetail]
    @SpaceId          INT,
    @DepositId        VARCHAR(64),
    @Page             INT,
    @PageSize         INT,
    @DateFrom         DATE         = NULL,
    @DateTo           DATE         = NULL,
    @TransactionType  VARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PaymentDepositId INT;
    SELECT @PaymentDepositId = [id]
    FROM   [dbo].[payment_deposit]
    WHERE  [space_id] = @SpaceId AND [deposit_id] = @DepositId AND [is_deleted] = 0;

    IF @PaymentDepositId IS NULL
    BEGIN
        RETURN; -- zero result sets -> caller treats as "not found"
    END

    -- Result set 1: summary header. Always exactly one row, even if result set 2 below
    -- comes back with zero rows for the given date/type filters.
    ;WITH ChargesInDeposit AS (
        SELECT pc.[id], pc.[merchant_net_amount], pc.[merchant_net_currency_id], pc.[currency_id], pc.[exchange_rate], pc.[payment_datetime]
        FROM   [dbo].[payment_charge] pc
        WHERE  TRY_CAST(pc.[deposit_id] AS INT) = @PaymentDepositId AND pc.[is_deleted] = 0
    )
    SELECT
        pd.[deposit_id]                         AS deposit_id,
        pd.[space_id]                           AS space_id,
        ISNULL(sp.[display_name], '')           AS space_name,
        sp.[entity_id]                          AS entity_id,
        en.[name_key]                           AS entity_name,
        -- Same Net-Amount-based total as usp_Deposit_Select — see that proc's comment for why
        -- raw merchant_net_amount can't be summed directly across charges.
        MAX(cur.[ISO])                           AS currency,
        SUM(
            CASE
                WHEN cid.[merchant_net_amount] IS NULL THEN NULL
                WHEN cid.[merchant_net_currency_id] IS NULL OR cid.[merchant_net_currency_id] = cid.[currency_id]
                    THEN CAST(cid.[merchant_net_amount] AS DECIMAL(18,4)) / POWER(10, COALESCE(mcur.[decimal_places], cur.[decimal_places]))
                WHEN cid.[exchange_rate] > 0
                    THEN ROUND((CAST(cid.[merchant_net_amount] AS DECIMAL(18,4)) / POWER(10, mcur.[decimal_places])) / cid.[exchange_rate], cur.[decimal_places])
                ELSE NULL
            END
        )                                         AS total_amount,   -- already MAJOR units
        COUNT(cid.[id])                          AS charge_count,
        MIN(cid.[payment_datetime])              AS first_charge_date,
        MAX(cid.[payment_datetime])              AS last_charge_date,
        pd.[document_original_file_name]        AS document_file_name,
        pd.[document_content_type]              AS document_content_type,
        pd.[document_file_size_bytes]           AS document_size_bytes,
        pd.[document_uploaded_by]               AS document_uploaded_by,
        pd.[document_uploaded_at]               AS document_uploaded_at
    FROM   [dbo].[payment_deposit] pd
    JOIN   [dbo].[space]  sp ON sp.[id] = pd.[space_id]
    JOIN   [dbo].[entity] en ON en.[id] = sp.[entity_id]
    LEFT JOIN ChargesInDeposit cid ON pd.[id] = @PaymentDepositId
    LEFT JOIN [dbo].[currency] cur  ON cur.[id]  = cid.[currency_id]
    LEFT JOIN [dbo].[currency] mcur ON mcur.[id] = cid.[merchant_net_currency_id]
    WHERE  pd.[id] = @PaymentDepositId
    GROUP BY pd.[deposit_id], pd.[space_id], sp.[display_name], sp.[entity_id], en.[name_key],
             pd.[document_original_file_name], pd.[document_content_type],
             pd.[document_file_size_bytes], pd.[document_uploaded_by], pd.[document_uploaded_at];

    -- Result set 2: paginated transactions in this deposit — the Purchase charge itself,
    -- plus any successful Refund events raised against it. @PaymentDepositId alone is now
    -- the join key — no @SpaceId re-check needed here, it was already verified above.
    -- Column set now mirrors usp_Transaction_Select's own Succeeded/Per-refund branches
    -- (including the same RunningRefunds cumulative-refund/status derivation) so this
    -- table can show the same columns Transaction History does — gateway, payment method,
    -- charged amount, gateway fee, FX rate, contract %, merchant net amount/currency
    -- (raw, minor-unit — NetAmount is computed in C#, same convention as GetTransactionsAsync),
    -- and refund reason. Previously this only returned amount_captured mislabeled as
    -- "Settled Amount" — every row showed the same charged figure, never the actual settlement.
    ;WITH RunningRefunds AS (
        SELECT
            pr.[id], pr.[payment_charge_id], pr.[amount], pr.[refund_datetime], pr.[provider_refund_id], pr.[reason],
            SUM(pr.[amount]) OVER (
                PARTITION BY pr.[payment_charge_id]
                ORDER BY pr.[refund_datetime], pr.[id]
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_refunded
        FROM [dbo].[payment_refund] pr
        WHERE pr.[status_id] = 2 AND pr.[is_deleted] = 0   -- refund_status: succeeded
    ),
    Combined AS (
        SELECT
            CAST(pi.[id] AS NVARCHAR(36)) AS payment_intent_id,
            CAST(pc.[id] AS NVARCHAR(36)) AS charge_id,
            'Purchase'                    AS transaction_type,
            'Succeeded'                   AS status,
            pc.[payment_datetime]         AS event_date,
            pg.[payment_gateway]          AS gateway,
            pc.[payment_method_type]      AS payment_method,
            pc.[payer_email]              AS customer,
            COALESCE(u.[display_name], u.[username]) AS customer_name,
            cur.[ISO]                     AS currency,
            pc.[currency_id]              AS currency_id,
            pc.[amount_captured]          AS amount,             -- Paid/Refund Amt
            pc.[amount_captured]          AS captured_amount,    -- Charged Amt
            pc.[gateway_fee_amount]       AS gateway_fee,
            pc.[exchange_rate]            AS exchange_rate,
            pc.[contract_percentage_applied] AS contract_percentage_applied,
            pc.[merchant_net_amount]      AS merchant_net_amount,
            mcur.[ISO]                    AS merchant_net_currency,
            CAST(NULL AS VARCHAR(500))    AS refund_reason
        FROM   [dbo].[payment_charge] pc
        JOIN   [dbo].[payment_intent] pi  ON pi.[id] = pc.[payment_intent_id]
        JOIN   [dbo].[orders]         o   ON o.[id]  = pi.[order_id]
        JOIN   [dbo].[payment_gateway] pg ON pg.[id] = pi.[payment_gateway_id]
        JOIN   [dbo].[currency]       cur ON cur.[id] = pc.[currency_id]
        LEFT JOIN [dbo].[user] u ON u.[id] = o.[user_id]
        LEFT JOIN [dbo].[currency] mcur ON mcur.[id] = pc.[merchant_net_currency_id]
        WHERE  TRY_CAST(pc.[deposit_id] AS INT) = @PaymentDepositId AND pc.[is_deleted] = 0

        UNION ALL

        SELECT
            CAST(pi.[id] AS NVARCHAR(36)), CAST(pc.[id] AS NVARCHAR(36)), 'Refund',
            CASE WHEN rr.[cumulative_refunded] >= pc.[amount_captured] THEN 'Fully Refunded' ELSE 'Partially Refunded' END,
            rr.[refund_datetime], pg.[payment_gateway], pc.[payment_method_type],
            pc.[payer_email], COALESCE(u.[display_name], u.[username]),
            cur.[ISO], pc.[currency_id],
            rr.[amount], pc.[amount_captured], pc.[gateway_fee_amount], pc.[exchange_rate],
            pc.[contract_percentage_applied], pc.[merchant_net_amount], mcur.[ISO],
            rr.[reason]
        FROM   RunningRefunds rr
        JOIN   [dbo].[payment_charge] pc  ON pc.[id] = rr.[payment_charge_id] AND pc.[is_deleted] = 0
        JOIN   [dbo].[payment_intent] pi  ON pi.[id] = pc.[payment_intent_id]
        JOIN   [dbo].[orders]         o   ON o.[id]  = pi.[order_id]
        JOIN   [dbo].[payment_gateway] pg ON pg.[id] = pi.[payment_gateway_id]
        JOIN   [dbo].[currency]       cur ON cur.[id] = pc.[currency_id]
        LEFT JOIN [dbo].[user] u ON u.[id] = o.[user_id]
        LEFT JOIN [dbo].[currency] mcur ON mcur.[id] = pc.[merchant_net_currency_id]
        WHERE  TRY_CAST(pc.[deposit_id] AS INT) = @PaymentDepositId
    ),
    Filtered AS (
        SELECT *, COUNT(*) OVER() AS total_count
        FROM   Combined
        WHERE  (@DateFrom IS NULL OR CAST(event_date AS DATE) >= @DateFrom)
          AND  (@DateTo   IS NULL OR CAST(event_date AS DATE) <= @DateTo)
          AND  (@TransactionType IS NULL OR transaction_type = @TransactionType)
    )
    SELECT payment_intent_id, charge_id, transaction_type, status, event_date, gateway,
           payment_method, customer, customer_name, currency, currency_id, amount,
           captured_amount, gateway_fee, exchange_rate, contract_percentage_applied,
           merchant_net_amount, merchant_net_currency, refund_reason, total_count
    FROM   Filtered
    ORDER BY event_date DESC
    OFFSET (@Page * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
