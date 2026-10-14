-- =====================================================================================
-- 3. New stored procedures — deposit + document metadata
-- =====================================================================================

CREATE   PROCEDURE [dbo].[usp_PaymentDeposit_Exists]
    @SpaceId   INT,
    @DepositId VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 1
    FROM   [dbo].[payment_deposit]
    WHERE  [space_id] = @SpaceId AND [deposit_id] = @DepositId AND [is_deleted] = 0;
END
