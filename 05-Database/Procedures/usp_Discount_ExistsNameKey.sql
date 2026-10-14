-- ============================================================
-- usp_Discount_ExistsNameKey
-- Duplicate name_key check for PUT â€” excludes the current discount id.
-- Returns 1 row if another discount in the space already has this name.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Discount_ExistsNameKey]
    @SpaceId    INT,
    @NameKey    NVARCHAR(450),
    @DiscountId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM discounts
    WHERE space_id = @SpaceId
      AND name_key = @NameKey
      AND id <> @DiscountId
      AND is_deleted = 0;
END
