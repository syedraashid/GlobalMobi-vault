CREATE   PROCEDURE [dbo].[usp_Campaign_GetCurrencyImpact]
    @SpaceId INT,
    @OldCurrencyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS EligibleCampaignCount
    FROM advertiser_campaign ac
    INNER JOIN advertiser a ON a.id = ac.advertiser_id
    WHERE a.space_id = @SpaceId
      AND a.is_deleted = 0
      AND ac.is_deleted = 0
      AND ac.currency_id = @OldCurrencyId;
END
