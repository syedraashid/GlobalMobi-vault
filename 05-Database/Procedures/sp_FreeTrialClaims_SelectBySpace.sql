------------------------------------------------------------------------
-- 4) sp_FreeTrialClaims_SelectBySpace — CMS Claims tab live/expired status
--
-- Optimization on top of the fix: free_trial_settings has UNIQUE(space_id),
-- so there is at most one settings row per space and the "is this space's
-- campaign currently live" check is identical for every claim row this
-- proc returns (they're all scoped to the same @SpaceId). The original
-- version re-ran that EXISTS check once PER ROW; this computes it ONCE
-- into @IsCampaignLive and reuses it, same result, one lookup instead of N.
-- Assumes a grant's space_id always matches its order's space_id, which
-- holds by construction (both are written together from the same
-- @spaceId in FreeTrialService/OrderRepository.FreeTrial.cs) — flagging
-- this since it's the one assumption the optimization relies on.
------------------------------------------------------------------------
CREATE   PROCEDURE [dbo].[sp_FreeTrialClaims_SelectBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsCampaignLive BIT = CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.free_trial_settings fts
        WHERE fts.space_id = @SpaceId
          AND fts.is_deleted = 0
          AND fts.[status]   = 'approved'
          AND fts.is_enabled = 1
          AND CAST(GETUTCDATE() AS DATE) BETWEEN fts.start_at AND fts.end_at
    ) THEN 1 ELSE 0 END;

    SELECT
        CAST(g.id AS VARCHAR(36)) AS grant_id,
        u.username AS user_name,
        g.item_id,
        g.package_id,
        i.name_key AS item_name_key,
        p.name_key AS package_name_key,
        g.claimed_at,
        CAST(o.id AS VARCHAR(36)) AS order_id,
        CASE WHEN @IsCampaignLive = 1 THEN 'active' ELSE 'expired' END AS live_status
    FROM dbo.orders o
    JOIN dbo.user_free_trial_grant_item g ON g.order_id = o.id AND g.is_deleted = 0
    JOIN dbo.transaction_type tt ON tt.id = o.transaction_type_id AND tt.[type] = 'trial'
    LEFT JOIN dbo.[user] u ON CAST(u.id AS VARCHAR(36)) = g.user_id AND u.is_deleted = 0
    LEFT JOIN dbo.item i ON i.id = g.item_id
    LEFT JOIN dbo.package p ON p.id = g.package_id
    WHERE o.space_id = @SpaceId AND o.is_deleted = 0
    ORDER BY g.claimed_at DESC;
END
