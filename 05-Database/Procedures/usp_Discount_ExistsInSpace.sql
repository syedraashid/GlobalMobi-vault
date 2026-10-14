-- ============================================================
-- usp_Discount_ExistsInSpace
-- Guard check before PUT / DELETE â€” returns 1 row if found.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Discount_ExistsInSpace]
    @DiscountId INT,
    @SpaceId    INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM discounts
    WHERE id = @DiscountId AND space_id = @SpaceId AND is_deleted = 0;
END
