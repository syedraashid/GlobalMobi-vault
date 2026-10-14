-- ── 9. Activity Log — Custom Booth Item entity-name lookup ────

CREATE   PROCEDURE [dbo].[sp_ActivityLog_GetEntityName]
    @EntityType NVARCHAR(100),
    @EntityId   NVARCHAR(100),
    @SpaceId    INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Id INT = TRY_CAST(@EntityId AS INT);
        IF @Id IS NULL
        BEGIN
            SELECT NULL AS value;
            COMMIT TRANSACTION;
            RETURN;
        END;

        IF @EntityType = 'Portal'
            SELECT TOP 1 i.value
            FROM   portal p WITH (NOLOCK)
            JOIN   i18n   i WITH (NOLOCK) ON i.[key] = p.text_field_key AND i.space_id = @SpaceId
            WHERE  p.id = @Id AND p.space_id = @SpaceId
            ORDER  BY CASE WHEN i.locale_id LIKE 'en%' THEN 0 ELSE 1 END, i.locale_id ASC;

        ELSE IF @EntityType IN ('Booth', 'Booth Media')
            SELECT TOP 1 i.value
            FROM   booth b WITH (NOLOCK)
            JOIN   i18n  i WITH (NOLOCK) ON i.[key] = b.name_key AND i.space_id = @SpaceId
            WHERE  b.id = @Id AND b.space_id = @SpaceId
            ORDER  BY CASE WHEN i.locale_id LIKE 'en%' THEN 0 ELSE 1 END, i.locale_id ASC;

        ELSE IF @EntityType = 'Custom Booth Item'
            SELECT TOP 1 i.value
            FROM   custom_booth_item c WITH (NOLOCK)
            JOIN   booth b WITH (NOLOCK) ON b.id = c.booth_id
            JOIN   i18n  i WITH (NOLOCK) ON i.[key] = c.name_key AND i.space_id = @SpaceId
            WHERE  c.id = @Id AND b.space_id = @SpaceId
            ORDER  BY CASE WHEN i.locale_id LIKE 'en%' THEN 0 ELSE 1 END, i.locale_id ASC;

        ELSE IF @EntityType = 'Charity'
            SELECT TOP 1 i.value
            FROM   charity c WITH (NOLOCK)
            JOIN   i18n    i WITH (NOLOCK) ON i.[key] = c.name_key AND i.space_id = @SpaceId
            WHERE  c.id = @Id AND c.space_id = @SpaceId
            ORDER  BY CASE WHEN i.locale_id LIKE 'en%' THEN 0 ELSE 1 END, i.locale_id ASC;

        ELSE IF @EntityType = 'Entity'
            SELECT TOP 1 i.value
            FROM   entity en WITH (NOLOCK)
            JOIN   i18n   i  WITH (NOLOCK) ON i.[key] = en.name_key AND i.space_id = @SpaceId
            WHERE  en.id = @Id AND en.space_id = @SpaceId
            ORDER  BY CASE WHEN i.locale_id LIKE 'en%' THEN 0 ELSE 1 END, i.locale_id ASC;

        ELSE IF @EntityType = 'Recognition'
            SELECT TOP 1 i.value
            FROM   predefined_comments pc WITH (NOLOCK)
            JOIN   i18n                 i WITH (NOLOCK) ON i.[key] = pc.comment_key AND i.space_id = @SpaceId
            WHERE  pc.id = @Id
            ORDER  BY CASE WHEN i.locale_id LIKE 'en%' THEN 0 ELSE 1 END, i.locale_id ASC;

        ELSE IF @EntityType = 'Teleport'
            SELECT TOP 1 i.value
            FROM   teleport_table t WITH (NOLOCK)
            JOIN   i18n           i WITH (NOLOCK) ON i.[key] = t.name_key AND i.space_id = @SpaceId
            WHERE  t.id = @Id AND t.space_id = @SpaceId
            ORDER  BY CASE WHEN i.locale_id LIKE 'en%' THEN 0 ELSE 1 END, i.locale_id ASC;

        ELSE
            SELECT NULL AS value;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
