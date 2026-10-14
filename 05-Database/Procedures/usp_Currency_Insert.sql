-- ============================================================
-- usp_Currency_Insert
-- Inserts a new active currency row.
-- Raises ISO_DUPLICATE (50000) if the ISO code already exists.
-- Returns: id (SCOPE_IDENTITY) as scalar.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Currency_Insert]
    @Name          VARCHAR(64),
    @ISO           VARCHAR(5),
    @Symbol        CHAR(5)     = NULL,
    @Delimiter     CHAR(1)     = '.',
    @DecimalPlaces TINYINT     = 2,
    @ModifiedBy    VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM currency WHERE ISO = @ISO AND is_deleted = 0)
    BEGIN
        RAISERROR('ISO_DUPLICATE', 16, 1);
        RETURN;
    END

    INSERT INTO currency (name, ISO, symbol, delimiter, decimal_places, modified_by)
    VALUES (@Name, @ISO, @Symbol, @Delimiter, @DecimalPlaces, @ModifiedBy);

    DECLARE @NewId INT = SCOPE_IDENTITY();
    SELECT id, name AS Name, ISO, symbol AS Symbol, delimiter AS Delimiter, decimal_places AS DecimalPlaces
    FROM currency WHERE id = @NewId;
END
