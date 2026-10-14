-- =====================================================================================
-- Migration: usp_Space_SelectById — resolve the space's own currency with an entity-level
-- fallback, without losing the "is this explicitly set on the space" signal.
-- =====================================================================================
-- Root cause this fixes: space.currency_id is nullable and, unlike entity.currency_id (which
-- always resolves — usp_admin_get_entity_config falls back to a hardcoded USD default when no
-- entity row exists), a space with no explicit currency_id simply returned no currency at all.
-- Confirmed read-only against the live DB: space 1 ("ProSoccer") has currency_id=2 (USD) set
-- directly; space 11 ("QPR", entity_id=11) has currency_id=NULL, while its OWN entity (11) has
-- currency_id=2 set — two genuinely separate columns on two separate tables, never synced.
--
-- The body below is the real, current definition (retrieved read-only via sp_helptext, not
-- guessed), with one addition: a LEFT JOIN to the space's entity and that entity's currency,
-- selected as a second, entity_-prefixed column set alongside the existing space-currency
-- columns. Both are still returned — OrderRepository callers must not collapse them into one
-- field, since the frontend needs to tell "space has its own override" apart from "inheriting
-- the entity's" (see SpaceRepository.GetSpaceByIdAsync's EffectiveCurrency computation).
-- =====================================================================================

CREATE   PROCEDURE [dbo].[usp_Space_SelectById]
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.id,
        s.platform_type_id,
        s.entity_id,
        s.sku,
        s.link,
        s.is_published,
        s.is_live,
        s.currency_id,
        s.description_key,
        s.modified_time,
        s.modified_by,
        c.ISO            AS currency_iso,
        c.symbol         AS currency_symbol,
        c.name           AS currency_name,
        c.delimiter      AS currency_delimiter,
        c.decimal_places AS currency_decimal_places,
        e.currency_id             AS entity_currency_id,            -- NEW
        ec.ISO                    AS entity_currency_iso,           -- NEW
        ec.symbol                 AS entity_currency_symbol,        -- NEW
        ec.name                   AS entity_currency_name,          -- NEW
        ec.delimiter              AS entity_currency_delimiter,     -- NEW
        ec.decimal_places         AS entity_currency_decimal_places,-- NEW
        i.locale_id,
        i.value
    FROM space s
    LEFT JOIN currency c  ON c.id  = s.currency_id
    LEFT JOIN entity   e  ON e.id  = s.entity_id       -- NEW
    LEFT JOIN currency ec ON ec.id = e.currency_id     -- NEW
    LEFT JOIN i18n i
        ON CONVERT(varchar(36), i.[key]) = s.description_key
       AND i.space_id = s.id
    WHERE s.id = @Id
    ORDER BY i.locale_id;
END
