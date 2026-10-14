-- ------------------------------------------------------------
-- 5) usp_Package_Insert / usp_Package_Update
--    NameKey/DescriptionKey are generated + upserted into i18n by the
--    calling C# code (PackageRepository.CreateAsync), same pattern
--    ItemRepository.AddAsync already uses — this proc just persists them.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_Package_Insert]
    @SpaceId         INT,
    @NameKey         UNIQUEIDENTIFIER,
    @DescriptionKey  UNIQUEIDENTIFIER = NULL,
    @ThumbMediaId    BIGINT,
    @BaseCost        BIGINT,
    @CurrencyId      INT,
    @TaxCategoryId   INT = NULL,
    @TaxIsInclusive  BIT = NULL,
    @IsAvailable     BIT = 1,
    @ModifiedBy      VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.package
        (space_id, name_key, description_key, thumbnail_media_id, base_cost, currency_id,
         tax_category_id, tax_is_inclusive, is_available, status, modified_by)
    VALUES
        (@SpaceId, @NameKey, @DescriptionKey, @ThumbMediaId, @BaseCost, @CurrencyId,
         @TaxCategoryId, @TaxIsInclusive, @IsAvailable, 'draft', @ModifiedBy);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS package_id;
END
