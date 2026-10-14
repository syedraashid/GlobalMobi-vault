CREATE   PROCEDURE [dbo].[sp_GameAnnouncementUserPrize_Add]
    @AnnouncementId   INT,
    @AssignmentsJson  NVARCHAR(MAX),
    @ModifiedBy       VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.game_announcement_user_prize AS target
    USING (
        SELECT @AnnouncementId AS announcement_id, UserId AS user_id, ItemId AS item_id, Quantity AS quantity
        FROM OPENJSON(@AssignmentsJson)
        WITH (
            UserId   UNIQUEIDENTIFIER '$.userId',
            ItemId   INT              '$.itemId',
            Quantity INT              '$.quantity'
        )
    ) AS src
    ON  target.announcement_id = src.announcement_id
    AND target.user_id         = src.user_id
    AND target.item_id         = src.item_id
    WHEN MATCHED THEN
        UPDATE SET quantity = src.quantity, is_deleted = 0, modified_by = @ModifiedBy, modified_time = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (announcement_id, user_id, item_id, quantity, modified_by)
        VALUES (src.announcement_id, src.user_id, src.item_id, src.quantity, @ModifiedBy);
END
