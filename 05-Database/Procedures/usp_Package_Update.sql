CREATE   PROCEDURE [dbo].[usp_Package_Update]
    @PackageId       INT,
    @ThumbMediaId    BIGINT      = NULL,
    @BaseCost        BIGINT      = NULL,
    @CurrencyId      INT         = NULL,
    @TaxCategoryId   INT         = NULL,
    @TaxIsInclusive  BIT         = NULL,
    @IsAvailable     BIT         = NULL,
    @Status          VARCHAR(20) = NULL,
    @ModifiedBy      VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.package
    SET
        thumbnail_media_id = COALESCE(@ThumbMediaId, thumbnail_media_id),
        base_cost          = COALESCE(@BaseCost, base_cost),
        currency_id        = COALESCE(@CurrencyId, currency_id),
        tax_category_id    = COALESCE(@TaxCategoryId, tax_category_id),
        tax_is_inclusive   = COALESCE(@TaxIsInclusive, tax_is_inclusive),
        is_available       = COALESCE(@IsAvailable, is_available),
        status             = COALESCE(@Status, status),
        modified_time      = SYSUTCDATETIME(),
        modified_by        = @ModifiedBy
    WHERE id = @PackageId;
END
