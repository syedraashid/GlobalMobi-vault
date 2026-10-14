-- ============================================================
-- usp_Discount_GetForUpdate
-- Lock-read before a PUT â€” returns id, space_id, name_key.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Discount_GetForUpdate]
    @DiscountId INT,
    @SpaceId    INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, space_id, name_key
    FROM discounts
    WHERE id = @DiscountId AND space_id = @SpaceId AND is_deleted = 0;
END
