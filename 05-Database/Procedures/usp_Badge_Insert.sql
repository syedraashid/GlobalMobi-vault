-- ============================================================
-- usp_Badge_Insert
-- Inserts the badge subtype row (id = item.id, no identity).
-- name_key and description_key are CHAR(36) GUID strings.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Badge_Insert]
    @ItemId         INT,
    @NameKey        CHAR(36),
    @DescriptionKey CHAR(36)      = NULL,
    @MediaId        BIGINT        = NULL,
    @ModifiedBy     NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO badge (id, name_key, description_key, media_id, modified_by)
    VALUES (@ItemId, @NameKey, @DescriptionKey, @MediaId, @ModifiedBy);
END
