-- ============================================================
-- usp_Discount_SelectById
-- Full discount record with item linkage and all i18n name rows.
-- C# collapses multiple locale rows into one DiscountDto.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Discount_SelectById]
    @DiscountId INT,
    @SpaceId    INT
AS
BEGIN
    SET NOCOUNT ON;
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
        ni.[value]          AS name_value,
        COALESCE(ca.[status], d.[status]) AS approval_status,
        ca.id               AS approval_id,
        ca.[action_type]    AS approval_action_type,
        ca.[current_snapshot]  AS current_snapshot,
        ca.[proposed_snapshot] AS proposed_snapshot,
        d.[status]             AS content_status
    FROM discounts d
    LEFT JOIN item_discounts id2
        ON id2.discount_id = d.id AND id2.is_deleted = 0
    LEFT JOIN supported_languages sl
        ON sl.space_id = d.space_id
    LEFT JOIN i18n ni
        ON ni.[key]       = CAST(d.name_key AS UNIQUEIDENTIFIER)
       AND ni.space_id    = d.space_id
       AND ni.locale_id   = sl.locale_id
       AND ni.is_deleted  = 0
    LEFT JOIN dbo.content_approval ca
        ON ca.content_type = 'discount' AND ca.content_id = d.id AND ca.[status] != 'withdrawn'
    WHERE d.id = @DiscountId AND d.space_id = @SpaceId AND d.is_deleted = 0
    ORDER BY sl.locale_id;
END
