CREATE   PROCEDURE [dbo].[usp_Space_SetExtraCcuEnabled]
    @SelectedSpaceIdsJson NVARCHAR(MAX),   -- e.g. "[104,106]" — JSON array, serialized straight from the C# List<int>
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    UPDATE s
    SET s.is_extra_ccu_enabled = CASE WHEN j.value IS NOT NULL THEN 1 ELSE 0 END,
        s.modified_by          = @ModifiedBy,
        s.modified_time        = SYSUTCDATETIME()
    FROM space s
    LEFT JOIN OPENJSON(@SelectedSpaceIdsJson) j ON TRY_CAST(j.value AS INT) = s.id
    WHERE s.is_deleted = 0;
END
