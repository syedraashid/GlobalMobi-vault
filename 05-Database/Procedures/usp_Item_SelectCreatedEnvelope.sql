-- ============================================================
-- usp_Item_SelectCreatedEnvelope
-- Lightweight read-back immediately after item creation.
-- Returns the minimal envelope: id, type, i18n keys, flags.
-- ============================================================
CREATE   PROCEDURE [dbo].[usp_Item_SelectCreatedEnvelope]
    @ItemId  INT,
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        i.id              AS item_id,
        i.item_type_id,
        i.name_key,
        i.description_key,
        i.is_available,
        i.tax_category_id
    FROM item i
    WHERE i.id = @ItemId AND i.space_id = @SpaceId
    ORDER BY i.id;
END
