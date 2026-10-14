-- ------------------------------------------------------------
-- 11) usp_UserInventory_Upsert — MERGE key extends from (user_id, item_id)
--     to (user_id, item_id, item_type_id), so a package id and a real
--     item id can never collide in this table. item_type_id is read
--     straight off order_line_item, no lookup needed.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_UserInventory_Upsert]
    @OrderId CHAR(36),
    @ModBy   VARCHAR(200) = 'system'
AS
BEGIN
    SET NOCOUNT ON;
    MERGE INTO dbo.user_inventory AS target
    USING (
        SELECT
            CAST(o.user_id AS VARCHAR(36))  AS user_id,
            TRY_CAST(ol.item_ref_id AS INT) AS item_id,
            ol.item_type_id                 AS item_type_id,
            SUM(ol.quantity)                AS quantity
        FROM dbo.order_line_item ol
        JOIN dbo.orders o ON CAST(o.id AS CHAR(36)) = ol.order_id
        WHERE CAST(ol.order_id AS CHAR(36)) = @OrderId
          AND ol.is_deleted = 0
          AND TRY_CAST(ol.item_ref_id AS INT) IS NOT NULL
        GROUP BY CAST(o.user_id AS VARCHAR(36)), ol.item_ref_id, ol.item_type_id
    ) AS src
    ON  target.user_id      = src.user_id
    AND target.item_id      = src.item_id
    AND target.item_type_id = src.item_type_id
    AND target.is_deleted   = 0
    WHEN MATCHED THEN
        UPDATE SET
            target.quantity      = target.quantity + src.quantity,
            target.modified_time = SYSUTCDATETIME(),
            target.modified_by   = @ModBy
    WHEN NOT MATCHED THEN
        INSERT (user_id, item_id, item_type_id, quantity, is_deleted, modified_time, modified_by)
        VALUES (src.user_id, src.item_id, src.item_type_id, src.quantity, 0, SYSUTCDATETIME(), @ModBy);
END
