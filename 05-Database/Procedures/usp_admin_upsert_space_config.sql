CREATE   PROCEDURE [dbo].[usp_admin_upsert_space_config]
    @SpaceId       INT,
    @Payments      BIT,
    @Events        BIT,
    @Advertisers   BIT,
    @AiModeration  BIT,
    @Selfies       BIT,
    @Lighting      BIT,
    @Items         BIT,
    @Rewards       BIT,
    @Charities     BIT,
    @Subscriptions BIT,
    @Recognition   BIT,
    @Booths        BIT,
    @Hosting       BIT,
    @Approvals     BIT,
    @ApiVersion    NVARCHAR(20),
    @UpdatedBy     INT,
    @CurrencyId    INT = NULL -- NEW: NULL clears the space's override (falls back to entity)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[space_config]
    SET    [payments]      = @Payments,
           [events]        = @Events,
           [advertisers]   = @Advertisers,
           [ai_moderation] = @AiModeration,
           [selfies]       = @Selfies,
           [lighting]      = @Lighting,
           [items]         = @Items,
           [rewards]       = @Rewards,
           [charities]     = @Charities,
           [subscriptions] = @Subscriptions,
           [recognition]   = @Recognition,
           [booths]        = @Booths,
           [hosting]       = @Hosting,
           [approvals]     = @Approvals,
           [api_version]   = @ApiVersion,
           [modified_at]   = GETUTCDATE(),
           [modified_by]   = @UpdatedBy
    WHERE  [space_id] = @SpaceId;

    IF @@ROWCOUNT = 0
        INSERT INTO [dbo].[space_config]
            ([space_id],[payments],[events],[advertisers],[ai_moderation],[selfies],[lighting],[items],[rewards],[charities],[subscriptions],[recognition],[booths],[hosting],[approvals],[api_version],[modified_by])
        VALUES
            (@SpaceId,@Payments,@Events,@Advertisers,@AiModeration,@Selfies,@Lighting,@Items,@Rewards,@Charities,@Subscriptions,@Recognition,@Booths,@Hosting,@Approvals,@ApiVersion,@UpdatedBy);

    -- NEW: space.currency_id lives on a different table entirely (not space_config) — kept as
    -- a plain, unconditional assignment so passing NULL explicitly clears the override.
    UPDATE [dbo].[space]
    SET    [currency_id] = @CurrencyId
    WHERE  [id] = @SpaceId;
END
