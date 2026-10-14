-- ============================================================
-- usp_DiscountType_Exists
-- Returns 1 row if the discount type id is valid.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_DiscountType_Exists]
    @DiscountTypeId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1 FROM discount_type WHERE id = @DiscountTypeId;
END
