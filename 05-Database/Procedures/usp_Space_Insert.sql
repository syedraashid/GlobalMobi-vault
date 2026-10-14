-- ============================================================
-- usp_Space_Insert
-- Inserts a new space row and returns the generated id via
-- OUTPUT INSERTED.id.  Caller handles i18n (usp_I18n_Upsert)
-- within the same transaction.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Space_Insert]
    @PlatformTypeId INT,
    @EntityId       INT,
    @Sku            VARCHAR(200)  = NULL,
    @Link           VARCHAR(500)  = NULL,
    @IsPublished    BIT,
    @IsLive         BIT,
    @CurrencyId     INT           = NULL,
    @DescriptionKey VARCHAR(36),
    @ModifiedBy     VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO space (
        platform_type_id, entity_id, sku, link,
        is_published, is_live, currency_id, description_key,
        modified_time, modified_by
    )
    OUTPUT INSERTED.id
    VALUES (
        @PlatformTypeId, @EntityId, @Sku, @Link,
        @IsPublished, @IsLive, @CurrencyId, @DescriptionKey,
        SYSUTCDATETIME(), @ModifiedBy
    );
END
