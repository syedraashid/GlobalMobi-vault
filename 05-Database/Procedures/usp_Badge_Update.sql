-- ============================================================
-- usp_Badge_Update
-- Updates badge subtype fields for an item.
-- All three value params are direct-assign (NULL allowed).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Badge_Update]
    @ItemId         INT,
    @MediaId        BIGINT        = NULL,
    @NameKey        CHAR(36)      = NULL,
    @DescriptionKey CHAR(36)      = NULL,
    @ModifiedBy     NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE badge
    SET
        media_id        = @MediaId,
        name_key        = @NameKey,
        description_key = @DescriptionKey,
        modified_by     = @ModifiedBy
    WHERE id = @ItemId;
END
