-- ============================================================
-- usp_Space_Update
-- Updates an existing space row and returns affected row count
-- (0 = not found).  Caller handles i18n (usp_I18n_Upsert)
-- within the same transaction.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Space_Update]
    @Id             INT,
    @PlatformTypeId INT,
    @EntityId       INT,
    @Sku            VARCHAR(200)  = NULL,
    @Link           VARCHAR(500)  = NULL,
    @IsPublished    BIT,
    @IsLive         BIT,
    @CurrencyId     INT           = NULL,
    @DescriptionKey VARCHAR(36)   = NULL,
    @ModifiedBy     VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE space
       SET platform_type_id = @PlatformTypeId,
           entity_id        = @EntityId,
           sku              = @Sku,
           link             = @Link,
           is_published     = @IsPublished,
           is_live          = @IsLive,
           currency_id      = @CurrencyId,
           description_key  = @DescriptionKey,
           modified_time    = SYSUTCDATETIME(),
           modified_by      = @ModifiedBy
     WHERE id = @Id;
    SELECT @@ROWCOUNT AS affected;
END
