-- =====================================================================================
-- 6. usp_Transaction_Select — updated in place (newly in scope for this revision)
-- =====================================================================================
-- The body below reproduces the definition actually deployed to fix the missing-parameter
-- error (multi-select @Status/@Gateway via STRING_SPLIT...IN, plus @TransactionType), with
-- two changes layered on top, applied identically in Branch 2 (Succeeded) and Branch 3
-- (Per-refund):
--   1. A LEFT JOIN back to payment_deposit to resolve pc.deposit_id (now a surrogate id,
--      stored as text) back to the human-readable deposit_id Finance originally typed. The
--      output column alias is still "deposit_id" and still occupies the same position, so
--      nothing downstream (the @Search filter, the final SELECT list, transaction_type/
--      total_count) changes at all.
--   2. A LEFT JOIN to the new DepositTotals CTE, exposing deposit_total_amount — the sum of
--      merchant_net_amount across every charge in the same deposit.
-- Branch 1 (Pending/Cancelled) has no charge yet, so both new columns are NULL placeholders
-- there, same as every other charge-only column in that branch.
-- =====================================================================================

CREATE   PROCEDURE [dbo].[usp_Transaction_Select]
    @SpaceIds        NVARCHAR(MAX) = NULL,
    @EntityIds       NVARCHAR(MAX) = NULL,
    @Page            INT           = 0,
    @PageSize        INT           = 10,
    @Search          NVARCHAR(255) = NULL,
    @Status          NVARCHAR(MAX) = NULL,
    @Gateway         NVARCHAR(MAX) = NULL,
    @TransactionType NVARCHAR(MAX) = NULL,
    @DateFrom        DATE          = NULL,
    @DateTo          DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    WITH RunningRefunds AS (
        SELECT
            pr.id,
            pr.payment_charge_id,
            pr.amount,
            pr.refund_datetime,
            pr.provider_refund_id,
            pr.reason,
            SUM(pr.amount) OVER (
                PARTITION BY pr.payment_charge_id
                ORDER BY pr.refund_datetime, pr.id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_refunded
        FROM payment_refund pr
        WHERE pr.status_id = 2 AND pr.is_deleted = 0
    ),

    DepositTotals AS (
        -- One row per deposit — summed directly off payment_charge, never off the
        -- AllTransactions UNION below, because a charge with N refund events produces N rows
        -- in Branch 3; summing across those would overcount that charge's contribution.
        -- Net-Amount-based, like usp_Deposit_Select/usp_Deposit_GetDetail's totals — settlement
        -- currency (merchant_net_currency_id) can differ per charge depending on gateway/
        -- method, so summing raw merchant_net_amount across charges would silently mix
        -- currencies; converting into each charge's own transaction currency first (same
        -- formula as TransactionChargeDto.NetAmount) makes the sum valid. Already MAJOR units.
        SELECT
            TRY_CAST(pc2.[deposit_id] AS INT) AS payment_deposit_id,
            SUM(
                CASE
                    WHEN pc2.[merchant_net_amount] IS NULL THEN NULL
                    WHEN pc2.[merchant_net_currency_id] IS NULL OR pc2.[merchant_net_currency_id] = pc2.[currency_id]
                        THEN CAST(pc2.[merchant_net_amount] AS DECIMAL(18,4)) / POWER(10, COALESCE(mcur2.[decimal_places], cur2.[decimal_places]))
                    WHEN pc2.[exchange_rate] > 0
                        THEN ROUND((CAST(pc2.[merchant_net_amount] AS DECIMAL(18,4)) / POWER(10, mcur2.[decimal_places])) / pc2.[exchange_rate], cur2.[decimal_places])
                    ELSE NULL
                END
            ) AS deposit_total_amount
        FROM   payment_charge pc2
        LEFT JOIN currency cur2  ON cur2.id  = pc2.currency_id
        LEFT JOIN currency mcur2 ON mcur2.id = pc2.merchant_net_currency_id
        WHERE  pc2.[deposit_id] IS NOT NULL AND pc2.[is_deleted] = 0
        GROUP BY TRY_CAST(pc2.[deposit_id] AS INT)
    ),

    AllTransactions AS (

        -- Branch 1: Pending / Cancelled — no charge exists yet
        SELECT
            CAST(pi.id AS NVARCHAR(36))          AS payment_intent_id,
            CAST(o.id  AS NVARCHAR(36))          AS order_id,
            CAST(o.user_id AS NVARCHAR(36))      AS user_id,
            o.space_id,
            CASE
                WHEN pi.status_id = 4 THEN 'Cancelled'
                ELSE 'Pending'
            END                                   AS status,
            pi.modified_time                      AS event_date,
            pg.payment_gateway                    AS gateway,
            CAST(NULL AS VARCHAR(50))             AS payment_method,
            CAST(NULL AS VARCHAR(255))            AS customer,
            COALESCE(u.display_name, u.username)  AS customer_name,
            cur.ISO                               AS currency,
            pi.currency_id,
            pi.amount                             AS amount,
            o.total_gross_amount,
            o.total_discount_amount,
            o.total_tax_amount,
            o.total_net_amount,
            CAST(NULL AS BIGINT)                  AS captured_amount,
            CAST(NULL AS BIGINT)                  AS gateway_fee,
            CAST(NULL AS VARCHAR(128))            AS provider_charge_id,
            CAST(NULL AS DATETIME2)               AS charge_date,
            CAST(NULL AS DECIMAL(18,6))           AS exchange_rate,
            CAST(NULL AS DECIMAL(5,2))            AS contract_percentage_applied,
            CAST(NULL AS BIGINT)                  AS merchant_net_amount,
            CAST(NULL AS VARCHAR(5))              AS merchant_net_currency,
            CAST(NULL AS NVARCHAR(36))            AS charge_id,
            CAST(NULL AS VARCHAR(64))             AS deposit_id,
            CAST(NULL AS DECIMAL(18,4))           AS deposit_total_amount,   -- matches DepositTotals' now-major-unit decimal type
            CAST(NULL AS BIGINT)                  AS refund_amount,
            CAST(NULL AS BIGINT)                  AS cumulative_refunded,
            CAST(NULL AS BIGINT)                  AS remaining_amount,
            CAST(NULL AS VARCHAR(128))            AS provider_refund_id,
            CAST(NULL AS VARCHAR(500))   AS refund_reason,
            CAST(NULL AS DATETIME2)               AS refund_date,
            ISNULL(sp.[display_name], '')         AS space_name,
            en.id                                  AS entity_id,
            en.[name_key]                         AS entity_name
        FROM payment_intent pi
        JOIN orders          o   ON o.id   = pi.order_id
        JOIN payment_gateway pg  ON pg.id  = pi.payment_gateway_id
        JOIN currency        cur ON cur.id = pi.currency_id
        JOIN [dbo].[space]   sp  ON sp.id  = o.space_id
        JOIN [dbo].[entity]  en  ON en.id  = sp.entity_id
        LEFT JOIN [dbo].[user] u ON u.id   = o.user_id
        WHERE (@SpaceIds  IS NULL OR o.space_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@SpaceIds,  ',')))
          AND (@EntityIds IS NULL OR o.space_id IN (SELECT s.id FROM [dbo].[space] s WHERE s.entity_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@EntityIds, ',')) AND s.is_deleted = 0))
          AND pi.is_deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM payment_charge pc2
              WHERE  pc2.payment_intent_id = pi.id
                AND  pc2.is_deleted        = 0
          )

        UNION ALL

        -- Branch 2: Succeeded — charge exists, real values from pc
        SELECT
            CAST(pi.id AS NVARCHAR(36))          AS payment_intent_id,
            CAST(o.id  AS NVARCHAR(36))          AS order_id,
            CAST(o.user_id AS NVARCHAR(36))      AS user_id,
            o.space_id,
            'Succeeded'                           AS status,
            pc.payment_datetime                   AS event_date,
            pg.payment_gateway                    AS gateway,
            pc.payment_method_type                AS payment_method,
            pc.payer_email                        AS customer,
            COALESCE(u.display_name, u.username)  AS customer_name,
            cur.ISO                               AS currency,
            pc.currency_id,
            pc.amount_captured                    AS amount,
            o.total_gross_amount,
            o.total_discount_amount,
            o.total_tax_amount,
            o.total_net_amount,
            pc.amount_captured                    AS captured_amount,
            pc.gateway_fee_amount                 AS gateway_fee,
            pc.provider_charge_id,
            pc.payment_datetime                   AS charge_date,
            pc.exchange_rate                      AS exchange_rate,
            pc.contract_percentage_applied        AS contract_percentage_applied,
            pc.merchant_net_amount                AS merchant_net_amount,
            mcur.ISO                              AS merchant_net_currency,
            CAST(pc.id AS NVARCHAR(36))           AS charge_id,
            pd.[deposit_id]                       AS deposit_id,             -- NEW: resolved from surrogate back to human text
            dt.[deposit_total_amount]             AS deposit_total_amount,   -- NEW
            CAST(NULL AS BIGINT)                  AS refund_amount,
            CAST(NULL AS BIGINT)                  AS cumulative_refunded,
            CAST(NULL AS BIGINT)                  AS remaining_amount,
            CAST(NULL AS VARCHAR(128))            AS provider_refund_id,
            CAST(NULL AS VARCHAR(500))            AS refund_reason,
            CAST(NULL AS DATETIME2)               AS refund_date,
            ISNULL(sp.[display_name], '')         AS space_name,
            en.id                                  AS entity_id,
            en.[name_key]                         AS entity_name
        FROM payment_charge pc
        JOIN payment_intent pi  ON pi.id  = pc.payment_intent_id
        JOIN orders          o   ON o.id  = pi.order_id
        JOIN payment_gateway pg  ON pg.id = pi.payment_gateway_id
        JOIN currency        cur ON cur.id = pc.currency_id
        JOIN [dbo].[space]   sp  ON sp.id = o.space_id
        JOIN [dbo].[entity]  en  ON en.id = sp.entity_id
        LEFT JOIN [dbo].[user]     u    ON u.id    = o.user_id
        LEFT JOIN currency         mcur ON mcur.id = pc.merchant_net_currency_id
        LEFT JOIN [dbo].[payment_deposit] pd ON pd.[id] = TRY_CAST(pc.deposit_id AS INT) AND pd.[is_deleted] = 0   -- NEW
        LEFT JOIN DepositTotals dt ON dt.[payment_deposit_id] = TRY_CAST(pc.deposit_id AS INT)                     -- NEW
        WHERE (@SpaceIds  IS NULL OR o.space_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@SpaceIds,  ',')))
          AND (@EntityIds IS NULL OR o.space_id IN (SELECT s.id FROM [dbo].[space] s WHERE s.entity_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@EntityIds, ',')) AND s.is_deleted = 0))
          AND pc.is_deleted = 0

        UNION ALL

        -- Branch 3: Per-refund event — same charge (pc) already in scope
        SELECT
            CAST(pi.id AS NVARCHAR(36))          AS payment_intent_id,
            CAST(o.id  AS NVARCHAR(36))          AS order_id,
            CAST(o.user_id AS NVARCHAR(36))      AS user_id,
            o.space_id,
            CASE
                WHEN rr.cumulative_refunded >= pc.amount_captured THEN 'Fully Refunded'
                ELSE 'Partially Refunded'
            END                                   AS status,
            rr.refund_datetime                    AS event_date,
            pg.payment_gateway                    AS gateway,
            pc.payment_method_type                AS payment_method,
            pc.payer_email                        AS customer,
            COALESCE(u.display_name, u.username)  AS customer_name,
            cur.ISO                               AS currency,
            pc.currency_id,
            rr.amount                             AS amount,
            o.total_gross_amount,
            o.total_discount_amount,
            o.total_tax_amount,
            o.total_net_amount,
            pc.amount_captured                    AS captured_amount,
            pc.gateway_fee_amount                 AS gateway_fee,
            pc.provider_charge_id,
            pc.payment_datetime                   AS charge_date,
            pc.exchange_rate                      AS exchange_rate,
            pc.contract_percentage_applied        AS contract_percentage_applied,
            pc.merchant_net_amount                AS merchant_net_amount,
            mcur.ISO                              AS merchant_net_currency,
            CAST(pc.id AS NVARCHAR(36))           AS charge_id,
            pd.[deposit_id]                       AS deposit_id,             -- NEW: resolved from surrogate back to human text
            dt.[deposit_total_amount]             AS deposit_total_amount,   -- NEW
            rr.amount                             AS refund_amount,
            rr.cumulative_refunded,
            pc.amount_captured - rr.cumulative_refunded AS remaining_amount,
            rr.provider_refund_id,
            rr.reason                             AS refund_reason,
            rr.refund_datetime                    AS refund_date,
            ISNULL(sp.[display_name], '')         AS space_name,
            en.id                                  AS entity_id,
            en.[name_key]                         AS entity_name
        FROM RunningRefunds rr
        JOIN payment_charge pc  ON pc.id  = rr.payment_charge_id AND pc.is_deleted = 0
        JOIN payment_intent pi  ON pi.id  = pc.payment_intent_id
        JOIN orders          o   ON o.id  = pi.order_id
        JOIN payment_gateway pg  ON pg.id = pi.payment_gateway_id
        JOIN currency        cur ON cur.id = pc.currency_id
        JOIN [dbo].[space]   sp  ON sp.id = o.space_id
        JOIN [dbo].[entity]  en  ON en.id = sp.entity_id
        LEFT JOIN [dbo].[user]     u    ON u.id    = o.user_id
        LEFT JOIN currency         mcur ON mcur.id = pc.merchant_net_currency_id
        LEFT JOIN [dbo].[payment_deposit] pd ON pd.[id] = TRY_CAST(pc.deposit_id AS INT) AND pd.[is_deleted] = 0   -- NEW
        LEFT JOIN DepositTotals dt ON dt.[payment_deposit_id] = TRY_CAST(pc.deposit_id AS INT)                     -- NEW
        WHERE (@SpaceIds  IS NULL OR o.space_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@SpaceIds,  ',')))
          AND (@EntityIds IS NULL OR o.space_id IN (SELECT s.id FROM [dbo].[space] s WHERE s.entity_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@EntityIds, ',')) AND s.is_deleted = 0))
    )

    SELECT
        payment_intent_id,
        order_id,
        user_id,
        space_id,
        status,
        event_date,
        gateway,
        payment_method,
        customer,
        customer_name,
        currency,
        currency_id,
        amount,
        total_gross_amount,
        total_discount_amount,
        total_tax_amount,
        total_net_amount,
        captured_amount,
        gateway_fee,
        provider_charge_id,
        charge_date,
        exchange_rate,
        contract_percentage_applied,
        merchant_net_amount,
        merchant_net_currency,
        charge_id,
        deposit_id,
        deposit_total_amount,
        refund_amount,
        cumulative_refunded,
        remaining_amount,
        provider_refund_id,
        refund_reason,
        refund_date,
        space_name,
        entity_id,
        entity_name,
        CASE
            WHEN status IN ('Partially Refunded', 'Fully Refunded') THEN 'Refund'
            ELSE 'Purchase'
        END AS transaction_type,
        COUNT(*) OVER() AS total_count
    FROM AllTransactions
    WHERE
        (@Status IS NULL OR status IN (SELECT value FROM STRING_SPLIT(@Status, ',')))
        AND (@Gateway IS NULL OR LOWER(gateway) IN (SELECT LOWER(value) FROM STRING_SPLIT(@Gateway, ',')))
        AND (@TransactionType IS NULL OR
             (CASE WHEN status IN ('Partially Refunded', 'Fully Refunded') THEN 'Refund' ELSE 'Purchase' END)
             IN (SELECT value FROM STRING_SPLIT(@TransactionType, ',')))
        AND (@DateFrom IS NULL OR CAST(event_date AS DATE) >= @DateFrom)
        AND (@DateTo   IS NULL OR CAST(event_date AS DATE) <= @DateTo)
        AND (@Search IS NULL
             OR payment_intent_id  LIKE '%' + @Search + '%'
             OR order_id           LIKE '%' + @Search + '%'
             OR customer           LIKE '%' + @Search + '%'
             OR customer_name      LIKE '%' + @Search + '%'
             OR provider_charge_id LIKE '%' + @Search + '%'
             OR deposit_id         LIKE '%' + @Search + '%')
    ORDER BY event_date DESC
    OFFSET (@Page * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
