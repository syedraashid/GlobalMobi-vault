CREATE   PROCEDURE [dbo].[sp_Item_SetPriceOnly]
    @ItemId      INT,
    @IsPriceOnly BIT,
    @ModifiedBy  VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.item
    SET is_price_only = @IsPriceOnly, modified_by = @ModifiedBy, modified_time = SYSUTCDATETIME()
    WHERE id = @ItemId;
END
