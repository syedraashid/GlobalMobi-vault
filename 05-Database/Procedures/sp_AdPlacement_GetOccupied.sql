-- ============================================================
-- AD PLACEMENT
-- ============================================================

-- ============================================================
-- sp_AdPlacement_GetOccupied  [NEW — was missing from all SQL files]
-- Returns distinct placement_key values for every slot already
-- booked by a non-deleted ad whose campaign overlaps the given
-- date window. Used by the CMS when assigning a placement to an
-- ad so the UI can disable already-taken slots.
-- Pass @ExcludeCampaignId when editing an existing campaign so
-- its own bookings do not block slot selection.
-- All non-deleted ads (draft/pending/approved) count as occupying
-- their slot — prevents double-booking at any workflow stage.
-- ============================================================
CREATE   PROCEDURE [dbo].[sp_AdPlacement_GetOccupied]
    @SpaceId           INT,
    @StartDate         DATE,
    @EndDate           DATE,
    @ExcludeCampaignId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT ap.[placement_key]
    FROM   [dbo].[advertiser_ad]        ad
    JOIN   [dbo].[ad_placement]         ap ON ap.[id]          = ad.[placement_id]
                                          AND ap.[space_id]    = @SpaceId
                                          AND ap.[is_deleted]  = 0
    JOIN   [dbo].[advertiser_campaign]  c  ON c.[id]           = ad.[campaign_id]
                                          AND c.[is_deleted]   = 0
                                          AND c.[start_date]   <= @EndDate
                                          AND c.[end_date]     >= @StartDate
    JOIN   [dbo].[advertiser]           a  ON a.[id]           = c.[advertiser_id]
                                          AND a.[is_deleted]   = 0
    WHERE  ad.[is_deleted]                          = 0
      AND  (@ExcludeCampaignId IS NULL OR c.[id] <> @ExcludeCampaignId)
    ORDER BY ap.[placement_key];
END;
