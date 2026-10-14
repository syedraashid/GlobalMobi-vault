/* 2. sp_Ad_PruneUnairedDates */
CREATE   PROCEDURE [dbo].[sp_Ad_PruneUnairedDates]
    @SpaceId INT,
    @AdId    INT,
    @Today   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @Today = ISNULL(@Today, CAST(SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time' AS DATE));

    -- Call this ONLY when an ad is approved for the first time (create approval): until then the ad never ran, so
    -- run dates that passed while it waited for approval never aired and must not become "history".
    -- Returns one row per date removed ('yyyy-MM-dd') so the caller can tell the submitter.
    DELETE s
    OUTPUT CONVERT(VARCHAR(10), deleted.run_date, 120) AS run_date
    FROM   ad_schedule_dates s
    INNER JOIN advertiser_ad ad          ON ad.id = s.ad_id AND ad.is_deleted = 0
    INNER JOIN advertiser_campaign c     ON c.id = ad.campaign_id
    INNER JOIN advertiser a              ON a.id = c.advertiser_id AND a.space_id = @SpaceId
    WHERE  s.ad_id = @AdId
      AND  s.is_deleted = 0
      AND  s.run_date < @Today;
END;
