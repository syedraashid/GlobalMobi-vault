-- Converts daily_rate/cost_per_day/total_cost (plain DECIMAL major-unit
-- values, unlike item_prices.base_cost) for campaigns priced in
-- OldCurrencyId. @Rate NULL => relabel only. duration_modifier is a
-- multiplier, not a currency amount, and is never touched.
CREATE   PROCEDURE [dbo].[usp_Campaign_BulkUpdateCurrencyBySpace]
    @SpaceId INT,
    @OldCurrencyId INT,
    @NewCurrencyId INT,
    @Rate DECIMAL(18,8) = NULL,
    @ModifiedBy VARCHAR(200) = 'system:currency-cascade'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Updated TABLE (CampaignId INT PRIMARY KEY, AdvertiserId INT);
    INSERT INTO @Updated (CampaignId, AdvertiserId)
    SELECT ac.id, ac.advertiser_id
    FROM advertiser_campaign ac
    INNER JOIN advertiser a ON a.id = ac.advertiser_id
    WHERE a.space_id = @SpaceId
      AND a.is_deleted = 0
      AND ac.is_deleted = 0
      AND ac.currency_id = @OldCurrencyId;

    UPDATE ac
    SET ac.currency_id   = @NewCurrencyId,
        ac.daily_rate    = CASE WHEN @Rate IS NOT NULL THEN ROUND(ac.daily_rate * @Rate, 2) ELSE ac.daily_rate END,
        ac.cost_per_day  = CASE WHEN @Rate IS NOT NULL THEN ROUND(ac.cost_per_day * @Rate, 2) ELSE ac.cost_per_day END,
        ac.total_cost    = CASE WHEN @Rate IS NOT NULL THEN ROUND(ac.total_cost * @Rate, 2) ELSE ac.total_cost END,
        ac.modified_by   = @ModifiedBy,
        ac.modified_time = SYSUTCDATETIME()
    FROM advertiser_campaign ac
    INNER JOIN @Updated u ON u.CampaignId = ac.id;

    SELECT CampaignId AS UpdatedCampaignId, AdvertiserId FROM @Updated;
END
