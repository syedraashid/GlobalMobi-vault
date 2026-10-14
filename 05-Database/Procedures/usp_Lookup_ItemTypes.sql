CREATE   PROCEDURE [dbo].[usp_Lookup_ItemTypes]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, type AS Type
    FROM item_type
    ORDER BY id;
END
