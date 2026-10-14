-- ============================================================
-- usp_I18n_Upsert
-- Inserts a new i18n row or updates value if the key+locale already exists.
-- Replaces:
--   ItemSql.InsertI18nValue, ItemSql.UpdateI18nValue, ItemSql.InsertI18nSimple
--   DiscountsSql.InsertI18n, DiscountsSql.UpdateI18nValue
--   ShopItemsSql.InsertI18nValue, ShopItemsSql.UpdateI18nValue
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_I18n_Upsert]
    @SpaceId   INT,
    @Key       UNIQUEIDENTIFIER,
    @LocaleId  NVARCHAR(20),
    @Value     NVARCHAR(MAX),
    @ModifiedBy NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM i18n
        WHERE space_id = @SpaceId AND [key] = @Key AND locale_id = @LocaleId
    )
    BEGIN
        UPDATE i18n
           SET [value]       = @Value,
               is_deleted    = 0,
               modified_time = SYSUTCDATETIME(),
               modified_by   = @ModifiedBy
         WHERE space_id  = @SpaceId
           AND [key]     = @Key
           AND locale_id = @LocaleId;
    END
    ELSE
    BEGIN
        INSERT INTO i18n (space_id, [key], locale_id, [value], modified_time, modified_by)
        VALUES (@SpaceId, @Key, @LocaleId, @Value, SYSUTCDATETIME(), @ModifiedBy);
    END
END
