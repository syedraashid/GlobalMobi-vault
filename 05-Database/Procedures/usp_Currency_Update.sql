-- ============================================================
-- usp_Currency_Update
-- Partial update: only non-NULL parameters overwrite the
-- existing column values (ISNULL pattern).
-- Raises NOT_FOUND (50000) if the currency is missing or soft-deleted.
-- Raises ISO_DUPLICATE (50000) if the new ISO collides with another row.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Currency_Update]
    @Id            INT,
    @Name          VARCHAR(64)  = NULL,
    @ISO           VARCHAR(5)   = NULL,
    @Symbol        CHAR(5)      = NULL,
    @Delimiter     CHAR(1)      = NULL,
    @DecimalPlaces TINYINT      = NULL,
    @ModifiedBy    VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM currency WHERE id = @Id AND is_deleted = 0)
    BEGIN
        RAISERROR('NOT_FOUND', 16, 1);
        RETURN;
    END

    IF @ISO IS NOT NULL
       AND EXISTS (SELECT 1 FROM currency WHERE ISO = @ISO AND is_deleted = 0 AND id <> @Id)
    BEGIN
        RAISERROR('ISO_DUPLICATE', 16, 1);
        RETURN;
    END

    UPDATE currency
    SET name           = ISNULL(@Name,          name),
        ISO            = ISNULL(@ISO,            ISO),
        symbol         = ISNULL(@Symbol,         symbol),
        delimiter      = ISNULL(@Delimiter,      delimiter),
        decimal_places = ISNULL(@DecimalPlaces,  decimal_places),
        modified_time  = sysutcdatetime(),
        modified_by    = @ModifiedBy
    WHERE id = @Id AND is_deleted = 0;

    SELECT id, name AS Name, ISO, symbol AS Symbol, delimiter AS Delimiter, decimal_places AS DecimalPlaces
    FROM currency WHERE id = @Id AND is_deleted = 0;
END
