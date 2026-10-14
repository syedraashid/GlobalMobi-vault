CREATE   PROCEDURE [dbo].[usp_Discount_SelectBySpace_Unity]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;

    SELECT
        d.id,
        d.space_id,
        d.discount_type_id,
        d.name_key,
        d.rate_pct,
        d.amount,
        d.start_at,
        d.end_at,
        d.metadata,
        d.created_time,
        d.created_by,
        d.modified_time,
        d.modified_by,
        id2.item_id         AS ItemId,
        sl.locale_id,
        ni.[value]          AS name_value
    FROM discounts d
    LEFT JOIN item_discounts id2
           ON id2.discount_id = d.id AND id2.is_deleted = 0
    LEFT JOIN supported_languages sl
           ON sl.space_id = d.space_id
    LEFT JOIN i18n ni
           ON ni.[key]      = CAST(d.name_key AS UNIQUEIDENTIFIER)
          AND ni.space_id   = d.space_id
          AND ni.locale_id  = sl.locale_id
          AND ni.is_deleted = 0
    WHERE d.space_id  = @SpaceId
      AND d.is_deleted = 0
      AND d.[status]   = 'approved'
    ORDER BY d.created_time, sl.locale_id;
END;


-- ============================================================
-- PORTAL LINKS (Unity sub-item — approved only)
-- ============================================================

-- ------------------------------------------------------------
-- sp_PortalLinks_GetApproved_Unity
-- Returns only approved portal links for the given portal IDs.
-- No portal_link_status column — approval metadata excluded.
-- ------------------------------------------------------------
