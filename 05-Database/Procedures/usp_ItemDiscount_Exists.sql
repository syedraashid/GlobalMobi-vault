-- ============================================================
-- usp_ItemDiscount_Exists
-- Returns 1 row if a discount with the given id exists.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_ItemDiscount_Exists]
    @DiscountId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1 FROM discounts WHERE id = @DiscountId;
END
