-- =====================================================================================
-- Migration: usp_admin_get_space_config / usp_admin_upsert_space_config — expose and let
-- Global Admin edit the space's own currency override from the Admin Portal's new
-- "Currency" tab (AdminPortal.jsx space-detail view, next to "Languages").
-- =====================================================================================
-- space.currency_id already exists and is already read (with an entity-level fallback) by
-- usp_Space_SelectById for the member-facing CurrencyContext — see
-- SpaceCurrencyEntityFallback_Migration.sql. This migration does not add a new column or a
-- new concept; it exposes that SAME column through the admin config surface so Global Admin
-- can set/clear it, since space_config (a separate table, feature flags + api_version only)
-- had no path to it. Clearing (NULL) makes the space inherit the entity's currency again.
--
-- Both bodies below are the real, current definitions (retrieved read-only via sp_helptext,
-- not guessed), with additions marked NEW.
-- =====================================================================================

CREATE   PROCEDURE [dbo].[usp_admin_get_space_config]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT sc.[payments], sc.[events],  sc.[advertisers], sc.[ai_moderation],
           sc.[selfies],  sc.[lighting], sc.[items],       sc.[rewards],
           sc.[charities],sc.[subscriptions],            sc.[recognition],
           sc.[booths],   sc.[hosting],  sc.[approvals],
           sc.[api_version],
           s.[currency_id] AS currency_id -- NEW: space's own currency override, NULL = inherit from entity
    FROM   [dbo].[space_config] sc
    LEFT JOIN [dbo].[space] s ON s.[id] = sc.[space_id] -- NEW
    WHERE  sc.[space_id] = @SpaceId;
END
