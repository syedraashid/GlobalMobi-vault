CREATE   PROCEDURE [dbo].[sp_AdPlacement_GetAvailabilityPerDay]
    @SpaceId     INT,
    @StartDate   DATE,
    @EndDate     DATE,
    @ExcludeAdId INT = NULL   -- for edit scenario: exclude this ad's own scheduled seconds
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ap.placement_key                              AS placement_key,
        ap.label                                      AS label,
        ap.is_3d                                      AS is_3d,
        sch.run_date                                  AS run_date,
        ISNULL(SUM(ad.duration_seconds), 0)           AS used_seconds,
        86400 - ISNULL(SUM(ad.duration_seconds), 0)   AS available_seconds
    FROM   ad_placement          ap
    LEFT JOIN advertiser_ad      ad  ON ad.placement_id = ap.id
                                    AND ad.is_deleted   = 0
                                    AND ad.[status]     = 'approved'
                                    AND (@ExcludeAdId IS NULL OR ad.id <> @ExcludeAdId)
    LEFT JOIN ad_schedule_dates  sch ON sch.ad_id       = ad.id
                                    AND sch.run_date    BETWEEN @StartDate AND @EndDate
                                    AND sch.is_deleted  = 0   -- SOFT-DELETE
    WHERE  ap.space_id   = @SpaceId
      AND  ap.is_deleted = 0
      AND  sch.run_date IS NOT NULL
    GROUP BY ap.placement_key, ap.label, ap.is_3d, sch.run_date
    ORDER BY ap.placement_key, sch.run_date;
END;
