CREATE   PROCEDURE [dbo].[sp_FreeTrialItem_GetPackageIdById]
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT package_id
    FROM dbo.free_trial_items
    WHERE id = @Id;
END
