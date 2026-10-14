-- ============================================================
-- usp_Discount_Delete
-- Hard deletes a discount row â€” used only when safe to do so.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Discount_Delete]
    @DiscountId INT,
    @SpaceId    INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM discounts
    WHERE id = @DiscountId AND space_id = @SpaceId;
END
