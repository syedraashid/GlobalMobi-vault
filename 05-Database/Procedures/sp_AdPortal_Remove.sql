CREATE   PROCEDURE [dbo].[sp_AdPortal_Remove]
    @AdId       INT,
    @ModifiedBy VARCHAR(36) = 'system'
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #AdPortalTargets (ad_id INT NOT NULL PRIMARY KEY);
    INSERT #AdPortalTargets (ad_id) VALUES (@AdId);
    EXEC dbo.sp_AdPortal_RemoveForAds @ModifiedBy = @ModifiedBy;
END
