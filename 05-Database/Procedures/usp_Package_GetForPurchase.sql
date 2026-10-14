-- ------------------------------------------------------------
-- 10) usp_Package_GetForPurchase — everything the order-construction
--     code needs in one round trip: the package's own price plus its tax
--     category/rate (result set 1) and its members' real (item_id,
--     item_type_id, quantity) (result set 2). Only returns a package that
--     is approved and available.
--     tax_category_id/rate_pct/tax_is_inclusive were missing here originally
--     (bug found 2026-09-17) — CreatePackageOrderAsync had no way to compute
--     tax at all, so every package purchase was charged tax-free regardless
--     of the Tax Category configured on the package in the CMS.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_Package_GetForPurchase]
    @PackageId INT,
    @SpaceId   INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.id          AS package_id,
        p.base_cost,
        p.currency_id,
        tc.id         AS tax_category_id,
        tc.rate_pct,
        p.tax_is_inclusive
    FROM dbo.package p
    LEFT JOIN dbo.tax_category tc ON tc.id = p.tax_category_id AND tc.is_deleted = 0
    WHERE p.id = @PackageId AND p.space_id = @SpaceId
      AND p.is_deleted = 0 AND p.[status] = 'approved' AND p.is_available = 1;

    -- Only APPROVED members — a pending/draft item-add must never be charged for or
    -- granted until the CMS approval workflow has actually signed off on it.
    SELECT
        pi.item_id,
        i.item_type_id,
        pi.quantity
    FROM dbo.package_item pi
    JOIN dbo.item i ON i.id = pi.item_id AND i.space_id = @SpaceId AND i.is_deleted = 0
    WHERE pi.package_id = @PackageId AND pi.is_deleted = 0 AND pi.status = 'approved';
END
