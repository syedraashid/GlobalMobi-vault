-- A6) sp_ItemCatalog_TrialEligibility_SelectBySpace — item_id IS NOT NULL
--     filter keeps this proc item-only now that package_id listings exist.
CREATE   PROCEDURE [dbo].[sp_ItemCatalog_TrialEligibility_SelectBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT fti.item_id, fts.end_at AS trial_ends_at
    FROM dbo.free_trial_settings fts
    JOIN dbo.free_trial_items fti
        ON fti.space_id = fts.space_id AND fti.is_deleted = 0 AND fti.[status] = 'approved'
       AND fti.item_id IS NOT NULL
    WHERE fts.space_id = @SpaceId
      AND fts.is_deleted = 0
      AND fts.[status]   = 'approved'
      AND fts.is_enabled = 1
      AND CAST(GETUTCDATE() AS DATE) BETWEEN fts.start_at AND fts.end_at;
END
