CREATE   PROCEDURE [dbo].[sp_TransactionType_GetIdByCode]
    @Code VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id FROM dbo.transaction_type WHERE [type] = @Code AND is_deleted = 0;
END
