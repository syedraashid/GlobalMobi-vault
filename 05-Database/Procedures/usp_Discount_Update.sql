-- ============================================================
-- usp_Discount_Update
-- COALESCE-based partial update â€” only non-NULL params are applied.
-- rate_pct and amount are direct-assign (NULL clears the field).
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Discount_Update]
    @DiscountId  INT,
    @SpaceId     INT,
    @NewTypeId   INT           = NULL,
    @NewNameKey  NVARCHAR(450) = NULL,
    @NewRatePct  DECIMAL(5,2)  = NULL,
    @NewAmount   BIGINT        = NULL,
    @NewStartAt  DATE          = NULL,
    @NewEndAt    DATE          = NULL,
    @NewMetadata NVARCHAR(MAX) = NULL,
    @ModifiedBy  NVARCHAR(255),
    @ForceStatus VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE discounts
    SET
        discount_type_id = COALESCE(@NewTypeId,   discount_type_id),
        name_key         = COALESCE(@NewNameKey,  name_key),
        rate_pct         = @NewRatePct,
        amount           = @NewAmount,
        start_at         = COALESCE(@NewStartAt,  start_at),
        end_at           = COALESCE(@NewEndAt,    end_at),
        metadata         = COALESCE(@NewMetadata, metadata),
        modified_time    = SYSUTCDATETIME(),
        modified_by      = @ModifiedBy,
        [status]         = ISNULL(@ForceStatus, [status])
    WHERE id = @DiscountId AND space_id = @SpaceId AND is_deleted = 0;
END
