CREATE   PROCEDURE [dbo].[sp_Entity_GetCurrencyIdBySpace]
    @SpaceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.currency_id
    FROM dbo.space  s
    JOIN dbo.entity e ON e.id = s.entity_id
    WHERE s.id = @SpaceId;
END
