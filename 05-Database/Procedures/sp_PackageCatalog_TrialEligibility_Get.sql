-- A7) sp_PackageCatalog_TrialEligibility_Get — package's own single-package
--     eligibility check, used at claim time.
CREATE   PROCEDURE [dbo].[sp_PackageCatalog_TrialEligibility_Get]
    @SpaceId   INT,
    @PackageId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT fts.end_at AS trial_ends_at
    FROM dbo.free_trial_settings fts
    JOIN dbo.free_trial_items fti
        ON fti.space_id = fts.space_id AND fti.is_deleted = 0 AND fti.[status] = 'approved'
       AND fti.package_id = @PackageId
    WHERE fts.space_id = @SpaceId
      AND fts.is_deleted = 0
      AND fts.[status]   = 'approved'
      AND fts.is_enabled = 1
      AND CAST(GETUTCDATE() AS DATE) BETWEEN fts.start_at AND fts.end_at;
END
