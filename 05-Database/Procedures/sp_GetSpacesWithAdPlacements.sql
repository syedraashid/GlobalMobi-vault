-- =============================================================================
-- File   : Data/Scripts/NotInDB/SP/08_AdScheduleBlobSPs.sql
-- SPs    : sp_GetSpacesWithAdPlacements
--          sp_GetAdDateWindowBlobsForSpace
--          sp_DeleteAdDateContentVersion
-- Used by: AdScheduleDailyJob (TifoXRCoreWebAPI — BackgroundService, runs every 24 h)
-- Purpose: Support the 3-day sliding window ad-date blob lifecycle.
--          Seeds D+1 blob and prunes D-2 blob once per day.
--
-- All SPs use CREATE OR ALTER — safe to re-run.
-- =============================================================================


-- =============================================================================
-- SP: sp_GetSpacesWithAdPlacements
-- Returns every distinct space_id that has at least one active ad placement.
-- Used by AdScheduleCronFunction to enumerate spaces that need D+1 seeding
-- and D-2 pruning each day.
-- =============================================================================
CREATE   PROCEDURE [dbo].[sp_GetSpacesWithAdPlacements]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT space_id
    FROM   ad_placement
    WHERE  is_deleted = 0;
END;
