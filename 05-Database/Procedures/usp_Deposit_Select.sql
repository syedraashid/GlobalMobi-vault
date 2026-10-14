-- =====================================================================================
-- 3b. New stored procedures — Deposits tab (list, detail drill-down, unassigned-charge picker)
-- =====================================================================================

CREATE   PROCEDURE [dbo].[usp_Deposit_Select]
    @SpaceIds     NVARCHAR(MAX) = NULL,
    @EntityIds    NVARCHAR(MAX) = NULL,
    @Page         INT           = 0,
    @PageSize     INT           = 10,
    @Search       NVARCHAR(200) = NULL,
    @HasDocument  BIT           = NULL,
    @DateFrom     DATE          = NULL,
    @DateTo       DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SpaceIdList  TABLE (Id INT);
    DECLARE @EntityIdList TABLE (Id INT);
    IF @SpaceIds  IS NOT NULL INSERT INTO @SpaceIdList  SELECT CAST(value AS INT) FROM STRING_SPLIT(@SpaceIds,  ',');
    IF @EntityIds IS NOT NULL INSERT INTO @EntityIdList SELECT CAST(value AS INT) FROM STRING_SPLIT(@EntityIds, ',');

    -- pd.id is a real, globally-unique surrogate again — a payment_charge row can only ever
    -- reference the one payment_deposit row it was assigned to (usp_Charge_AssignDepositId
    -- only ever creates/resolves a row scoped to the space it already validated), so unlike
    -- the free-text-join design this replaces, no separate space-guard CTE is needed here.
    ;WITH DepositGroups AS (
        SELECT
            pd.[deposit_id]                 AS deposit_id,
            pd.[space_id]                   AS space_id,
            ISNULL(sp.[display_name], '')   AS space_name,
            sp.[entity_id]                   AS entity_id,
            en.[name_key]                    AS entity_name,     -- matches usp_Transaction_Select's own entity_name output verbatim
            -- Reports in the CHARGE's own transaction currency (cur), not the merchant
            -- settlement currency (mcur) — settlement currency can legitimately differ per
            -- charge depending on gateway/method, so summing raw merchant_net_amount across
            -- charges would silently mix currencies. Net Amount (below) is merchant_net_amount
            -- converted into this same transaction currency for exactly this reason — see
            -- TransactionChargeDto.NetAmount's own doc comment for the identical rationale.
            MAX(cur.[ISO])                   AS currency,
            SUM(
                CASE
                    WHEN pc.[merchant_net_amount] IS NULL THEN NULL
                    WHEN pc.[merchant_net_currency_id] IS NULL OR pc.[merchant_net_currency_id] = pc.[currency_id]
                        THEN CAST(pc.[merchant_net_amount] AS DECIMAL(18,4)) / POWER(10, COALESCE(mcur.[decimal_places], cur.[decimal_places]))
                    WHEN pc.[exchange_rate] > 0
                        THEN ROUND((CAST(pc.[merchant_net_amount] AS DECIMAL(18,4)) / POWER(10, mcur.[decimal_places])) / pc.[exchange_rate], cur.[decimal_places])
                    ELSE NULL
                END
            )                                 AS total_amount,   -- already MAJOR units (a decimal sum of per-charge Net Amounts), not minor units
            COUNT(pc.[id])                   AS charge_count,
            MIN(pc.[payment_datetime])       AS first_charge_date,
            MAX(pc.[payment_datetime])       AS last_charge_date,
            MAX(pd.[document_original_file_name]) AS document_file_name,
            MAX(pd.[document_content_type])       AS document_content_type,
            MAX(pd.[document_file_size_bytes])    AS document_size_bytes,
            MAX(pd.[document_uploaded_by])        AS document_uploaded_by,
            MAX(pd.[document_uploaded_at])        AS document_uploaded_at
        FROM   [dbo].[payment_deposit] pd
        JOIN   [dbo].[space]  sp ON sp.[id] = pd.[space_id]
        JOIN   [dbo].[entity] en ON en.[id] = sp.[entity_id]
        LEFT JOIN [dbo].[payment_charge] pc
               ON TRY_CAST(pc.[deposit_id] AS INT) = pd.[id] AND pc.[is_deleted] = 0
        LEFT JOIN [dbo].[currency] cur  ON cur.[id]  = pc.[currency_id]
        LEFT JOIN [dbo].[currency] mcur ON mcur.[id] = pc.[merchant_net_currency_id]
        WHERE  pd.[is_deleted] = 0
          AND  (@SpaceIds  IS NULL OR pd.[space_id]  IN (SELECT Id FROM @SpaceIdList))
          AND  (@EntityIds IS NULL OR sp.[entity_id] IN (SELECT Id FROM @EntityIdList))
          AND  (@Search    IS NULL OR pd.[deposit_id] LIKE '%' + @Search + '%')
          AND  (@DateFrom  IS NULL OR CAST(pc.[payment_datetime] AS DATE) >= @DateFrom)
          AND  (@DateTo    IS NULL OR CAST(pc.[payment_datetime] AS DATE) <= @DateTo)
        GROUP BY pd.[deposit_id], pd.[space_id], sp.[display_name], sp.[entity_id], en.[name_key]
    )
    SELECT *, COUNT(*) OVER() AS total_count
    FROM   DepositGroups
    WHERE  (@HasDocument IS NULL
            OR (@HasDocument = 1 AND document_file_name IS NOT NULL)
            OR (@HasDocument = 0 AND document_file_name IS NULL))
    ORDER BY last_charge_date DESC
    OFFSET (@Page * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
