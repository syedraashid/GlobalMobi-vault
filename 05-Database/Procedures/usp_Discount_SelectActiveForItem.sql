-- ============================================================
-- usp_Discount_SelectActiveForItem
-- Returns ALL active global discounts for an item ordered by the
-- time each discount was assigned to the item (created_time ASC).
-- C# stacks them in that order: each row reduces the running price further.
-- Returns 0 rows if no active discount — C# treats as no discount.
--
-- C# applies each row:
--   type 1 (Percentage):   effectivePrice -= FLOOR(effectivePrice * rate_pct / 100)
--   type 2 (Fixed Amount): effectivePrice  = MAX(0, effectivePrice - amount)
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Discount_SelectActiveForItem]
    @ItemRefId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.discount_type_id,
        d.rate_pct,
        d.amount
    FROM item_discounts idis
    JOIN discounts d ON d.id = idis.discount_id
    WHERE idis.item_id    = @ItemRefId
      AND idis.region_id  IS NULL
      AND d.is_deleted    = 0
      AND d.[status]      = 'approved'
      AND idis.is_deleted = 0
      AND (d.start_at IS NULL OR CAST(SYSUTCDATETIME() AS date) >= d.start_at)
      AND (d.end_at   IS NULL OR CAST(SYSUTCDATETIME() AS date) <= d.end_at)
    ORDER BY
        idis.created_time ASC;
END
