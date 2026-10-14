-- ------------------------------------------------------------
-- 4b) usp_Order_InsertLine — add optional @PackageId param, defaults to
--     NULL so every existing caller (which never passes it) is completely
--     unaffected. Only the new package-purchase order-construction code
--     (OrderRepository.Package.cs) ever supplies a value.
-- ------------------------------------------------------------
CREATE   PROCEDURE [dbo].[usp_Order_InsertLine]
    @Id         UNIQUEIDENTIFIER,
    @OrderId    UNIQUEIDENTIFIER,
    @ItemTypeId INT,
    @ItemRefId  VARCHAR(36),
    @ShopId     INT           = NULL,
    @Qty        INT,
    @UnitAmount BIGINT,
    @CcyId      INT           = NULL,  -- accepted for C# compatibility, not stored
    @EntityId   INT           = NULL,  -- accepted for C# compatibility, not stored
    @Meta       NVARCHAR(MAX) = NULL,
    @PackageId  INT           = NULL,  -- NEW: set only on a member line granted as part of a package purchase
    @ModBy      VARCHAR(36)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Ticket-specific stock + event-capacity guard (item_type_id = 2 => Ticket).
        IF @ItemTypeId = 2
        BEGIN
            DECLARE @EventId INT, @Capacity INT;
            SELECT @EventId = t.event_id FROM dbo.ticket t WHERE t.id = TRY_CAST(@ItemRefId AS INT);

            IF @EventId IS NOT NULL
            BEGIN
                SELECT @Capacity = capacity FROM [dbo].[event] WITH (UPDLOCK, HOLDLOCK) WHERE id = @EventId;

                IF @Capacity IS NOT NULL
                BEGIN
                    DECLARE @SoldForEvent INT;
                    SELECT @SoldForEvent = ISNULL(SUM(ol.quantity), 0)
                    FROM dbo.order_line_item ol
                    JOIN dbo.ticket tk ON TRY_CAST(ol.item_ref_id AS INT) = tk.id
                    WHERE tk.event_id = @EventId AND ol.is_deleted = 0;

                    IF @SoldForEvent + @Qty > @Capacity
                        THROW 51002, 'EVENT_AT_CAPACITY', 1;
                END;

                IF @ShopId IS NOT NULL
                BEGIN
                    DECLARE @StockQty INT, @SoldForListing INT;
                    SELECT @StockQty = stock_quantity FROM dbo.shop_items
                    WHERE shop_id = @ShopId AND item_id = TRY_CAST(@ItemRefId AS INT);

                    IF @StockQty IS NOT NULL
                    BEGIN
                        SELECT @SoldForListing = ISNULL(SUM(quantity), 0)
                        FROM dbo.order_line_item
                        WHERE shop_id = @ShopId AND item_ref_id = @ItemRefId AND is_deleted = 0;

                        IF @SoldForListing + @Qty > @StockQty
                            THROW 51001, 'TICKET_SOLD_OUT', 1;
                    END;
                END;
            END;
        END;

        INSERT INTO dbo.order_line_item
        (id, order_id, item_type_id, item_ref_id, shop_id,
         quantity, unit_amount, metadata, package_id,
         is_deleted, modified_time, modified_by)
        VALUES
        (@Id, @OrderId, @ItemTypeId, @ItemRefId, @ShopId,
         @Qty, @UnitAmount, @Meta, @PackageId,
         0, SYSUTCDATETIME(), @ModBy);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
