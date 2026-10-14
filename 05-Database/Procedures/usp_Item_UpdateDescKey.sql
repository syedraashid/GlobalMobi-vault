-- ============================================================
-- usp_Item_UpdateDescKey
-- Updates only the description_key column — called when a new
-- description key is assigned during UpdateAsync (item had none before).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Item_UpdateDescKey]
    @ItemId         INT,
    @SpaceId        INT,
    @DescriptionKey CHAR(36),
    @ModifiedBy     NVARCHAR(255),
    @ForceStatus    VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE item
    SET    description_key = @DescriptionKey,
           modified_by     = @ModifiedBy,
           modified_time   = SYSUTCDATETIME(),
           [status]        = ISNULL(@ForceStatus, [status])
    WHERE id = @ItemId AND space_id = @SpaceId;
END
