-- A4) sp_FreeTrialItem_ExistsForPackage
CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_ExistsForPackage]
    @SpaceId   INT,
    @PackageId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) 1
    FROM dbo.free_trial_items
    WHERE space_id = @SpaceId AND package_id = @PackageId AND is_deleted = 0;
END
