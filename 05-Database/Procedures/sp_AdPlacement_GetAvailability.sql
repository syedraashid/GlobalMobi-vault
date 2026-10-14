-- Two result sets. Calculation (capacity, used, available) is done in the service layer.
-- RS1: all non-deleted placements for the space.
-- RS2: placement_id + duration_seconds for every non-deleted ad whose campaign overlaps
--      the date range, from a non-deleted advertiser. Pass @ExcludeAdId when editing an
--      ad so its own seconds are excluded from the sum.
CREATE   PROCEDURE [dbo].[sp_AdPlacement_GetAvailability]
    @SpaceId     INT,
    @StartDate   DATE,
    @EndDate     DATE,
    @ExcludeAdId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- RS1: placements
    SELECT id AS placement_id, placement_key, label, is_3d
    FROM   ad_placement
    WHERE  space_id  = @SpaceId
      AND  is_deleted = 0
    ORDER BY placement_key;

    -- RS2: raw ad durations for overlapping campaigns
    SELECT ad.placement_id, ad.duration_seconds
    FROM   advertiser_ad ad
    INNER JOIN ad_placement ap
        ON  ap.id        = ad.placement_id
        AND ap.space_id  = @SpaceId
        AND ap.is_deleted = 0
    INNER JOIN advertiser_campaign c
        ON  c.id         = ad.campaign_id
        AND c.is_deleted = 0
        AND c.start_date <= @EndDate
        AND c.end_date   >= @StartDate
    INNER JOIN advertiser a
        ON  a.id         = c.advertiser_id
        AND a.is_deleted = 0
    WHERE  ad.is_deleted = 0
      AND  (@ExcludeAdId IS NULL OR ad.id <> @ExcludeAdId);
END;
