-- =============================================================================
-- SECTION 12 — Stored Procedures: Transaction (global_admin nullable SpaceId)
-- @SpaceId = NULL → global_admin bypass: returns transactions across all spaces.
-- Three UNION branches (Pending/Cancelled, Succeeded, Per-refund) each updated.
-- =============================================================================

CREATE   PROCEDURE [dbo].[usp_Transaction_SelectBySpace]
    @SpaceId    INT             = NULL,
    @Page       INT             = 0,
    @PageSize   INT             = 10,
    @Search     NVARCHAR(255)   = NULL,
    @Status     VARCHAR(30)     = NULL,
    @Gateway    VARCHAR(50)     = NULL,
    @DateFrom   DATE            = NULL,
    @DateTo     DATE            = NULL
AS
BEGIN
    SET NOCOUNT ON;

    WITH RunningRefunds AS (
        SELECT
            pr.[id],
            pr.[payment_charge_id],
            pr.[amount],
            pr.[refund_datetime],
            pr.[provider_refund_id],
            pr.[reason],
            SUM(pr.[amount]) OVER (
                PARTITION BY pr.[payment_charge_id]
                ORDER BY pr.[refund_datetime], pr.[id]
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_refunded
        FROM [dbo].[payment_refund] pr
        WHERE pr.[status_id]   = 2
          AND pr.[is_deleted]  = 0
    ),

    AllTransactions AS (

        -- Branch 1: Pending / Cancelled
        SELECT
            CAST(pi.[id]       AS NVARCHAR(36))  AS payment_intent_id,
            CAST(o.[id]        AS NVARCHAR(36))  AS order_id,
            CAST(o.[user_id]   AS NVARCHAR(36))  AS user_id,
            CASE WHEN pi.[status_id] = 4 THEN 'Cancelled' ELSE 'Pending' END AS status,
            pi.[modified_time]                   AS event_date,
            pg.[payment_gateway]                 AS gateway,
            CAST(NULL AS VARCHAR(50))            AS payment_method,
            CAST(NULL AS VARCHAR(255))           AS customer,
            cur.[ISO]                            AS currency,
            pi.[currency_id],
            pi.[amount]                          AS amount,
            o.[total_gross_amount],
            o.[total_discount_amount],
            o.[total_tax_amount],
            o.[total_net_amount],
            CAST(NULL AS BIGINT)                 AS captured_amount,
            CAST(NULL AS BIGINT)                 AS gateway_fee,
            CAST(NULL AS VARCHAR(128))           AS provider_charge_id,
            CAST(NULL AS DATETIME2)              AS charge_date,
            CAST(NULL AS BIGINT)                 AS refund_amount,
            CAST(NULL AS BIGINT)                 AS cumulative_refunded,
            CAST(NULL AS BIGINT)                 AS remaining_amount,
            CAST(NULL AS VARCHAR(128))           AS provider_refund_id,
            CAST(NULL AS VARCHAR(500))           AS refund_reason,
            CAST(NULL AS DATETIME2)              AS refund_date
        FROM [dbo].[payment_intent]  pi
        JOIN [dbo].[orders]          o   ON o.[id]   = pi.[order_id]
        JOIN [dbo].[payment_gateway] pg  ON pg.[id]  = pi.[payment_gateway_id]
        JOIN [dbo].[currency]        cur ON cur.[id] = pi.[currency_id]
        WHERE (@SpaceId IS NULL OR o.[space_id] = @SpaceId)
          AND pi.[is_deleted] = 0
          AND NOT EXISTS (
              SELECT 1 FROM [dbo].[payment_charge] pc2
              WHERE pc2.[payment_intent_id] = pi.[id]
                AND pc2.[is_deleted]        = 0
          )

        UNION ALL

        -- Branch 2: Succeeded
        SELECT
            CAST(pi.[id]       AS NVARCHAR(36))  AS payment_intent_id,
            CAST(o.[id]        AS NVARCHAR(36))  AS order_id,
            CAST(o.[user_id]   AS NVARCHAR(36))  AS user_id,
            'Succeeded'                          AS status,
            pc.[payment_datetime]                AS event_date,
            pg.[payment_gateway]                 AS gateway,
            pc.[payment_method_type]             AS payment_method,
            pc.[payer_email]                     AS customer,
            cur.[ISO]                            AS currency,
            pc.[currency_id],
            pc.[amount_captured]                 AS amount,
            o.[total_gross_amount],
            o.[total_discount_amount],
            o.[total_tax_amount],
            o.[total_net_amount],
            pc.[amount_captured]                 AS captured_amount,
            pc.[gateway_fee_amount]              AS gateway_fee,
            pc.[provider_charge_id],
            pc.[payment_datetime]                AS charge_date,
            CAST(NULL AS BIGINT)                 AS refund_amount,
            CAST(NULL AS BIGINT)                 AS cumulative_refunded,
            CAST(NULL AS BIGINT)                 AS remaining_amount,
            CAST(NULL AS VARCHAR(128))           AS provider_refund_id,
            CAST(NULL AS VARCHAR(500))           AS refund_reason,
            CAST(NULL AS DATETIME2)              AS refund_date
        FROM [dbo].[payment_charge]  pc
        JOIN [dbo].[payment_intent]  pi  ON pi.[id]  = pc.[payment_intent_id]
        JOIN [dbo].[orders]          o   ON o.[id]   = pi.[order_id]
        JOIN [dbo].[payment_gateway] pg  ON pg.[id]  = pi.[payment_gateway_id]
        JOIN [dbo].[currency]        cur ON cur.[id] = pc.[currency_id]
        WHERE (@SpaceId IS NULL OR o.[space_id] = @SpaceId)
          AND pc.[is_deleted] = 0

        UNION ALL

        -- Branch 3: Per-refund event
        SELECT
            CAST(pi.[id]       AS NVARCHAR(36))  AS payment_intent_id,
            CAST(o.[id]        AS NVARCHAR(36))  AS order_id,
            CAST(o.[user_id]   AS NVARCHAR(36))  AS user_id,
            CASE
                WHEN rr.cumulative_refunded >= pc.[amount_captured] THEN 'Fully Refunded'
                ELSE 'Partially Refunded'
            END                                  AS status,
            rr.[refund_datetime]                 AS event_date,
            pg.[payment_gateway]                 AS gateway,
            pc.[payment_method_type]             AS payment_method,
            pc.[payer_email]                     AS customer,
            cur.[ISO]                            AS currency,
            pc.[currency_id],
            rr.[amount]                          AS amount,
            o.[total_gross_amount],
            o.[total_discount_amount],
            o.[total_tax_amount],
            o.[total_net_amount],
            pc.[amount_captured]                 AS captured_amount,
            pc.[gateway_fee_amount]              AS gateway_fee,
            pc.[provider_charge_id],
            pc.[payment_datetime]                AS charge_date,
            rr.[amount]                          AS refund_amount,
            rr.cumulative_refunded,
            pc.[amount_captured] - rr.cumulative_refunded AS remaining_amount,
            rr.[provider_refund_id],
            rr.[reason]                          AS refund_reason,
            rr.[refund_datetime]                 AS refund_date
        FROM RunningRefunds              rr
        JOIN [dbo].[payment_charge]  pc  ON pc.[id]  = rr.[payment_charge_id] AND pc.[is_deleted] = 0
        JOIN [dbo].[payment_intent]  pi  ON pi.[id]  = pc.[payment_intent_id]
        JOIN [dbo].[orders]          o   ON o.[id]   = pi.[order_id]
        JOIN [dbo].[payment_gateway] pg  ON pg.[id]  = pi.[payment_gateway_id]
        JOIN [dbo].[currency]        cur ON cur.[id] = pc.[currency_id]
        WHERE (@SpaceId IS NULL OR o.[space_id] = @SpaceId)
    )

    SELECT
        payment_intent_id, order_id, user_id, status, event_date,
        gateway, payment_method, customer, currency, currency_id,
        amount, total_gross_amount, total_discount_amount,
        total_tax_amount, total_net_amount, captured_amount,
        gateway_fee, provider_charge_id, charge_date,
        refund_amount, cumulative_refunded, remaining_amount,
        provider_refund_id, refund_reason, refund_date,
        COUNT(*) OVER () AS total_count
    FROM AllTransactions
    WHERE
        (@Status   IS NULL OR status                        = @Status)
        AND (@Gateway  IS NULL OR LOWER(gateway)            = LOWER(@Gateway))
        AND (@DateFrom IS NULL OR CAST(event_date AS DATE) >= @DateFrom)
        AND (@DateTo   IS NULL OR CAST(event_date AS DATE) <= @DateTo)
        AND (@Search   IS NULL
             OR payment_intent_id  LIKE '%' + @Search + '%'
             OR order_id           LIKE '%' + @Search + '%'
             OR customer           LIKE '%' + @Search + '%'
             OR provider_charge_id LIKE '%' + @Search + '%')
    ORDER BY event_date DESC
    OFFSET (@Page * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
