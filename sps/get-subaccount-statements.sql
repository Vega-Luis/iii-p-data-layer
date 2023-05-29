-- SP
-- Gets the subaccountStatements from a selected physical card
CREATE PROCEDURE dbo.GetSubAccountStatements
	@inPhysicalCardCode VARCHAR(16)
	, @inPostUser VARCHAR(64)
	, @inPostIp VARCHAR(64)
	, @outResultCode INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		DECLARE @LogDescription VARCHAR(256) = 
                        '{Action Type = Get subaccount statements'
						+ 'Description = ' 
						+ @inPhysicalCardCode + '}'

		DECLARE @postIdUser INT;
        SET @outResultCode = 0;                     -- No error code

        SELECT
            SA.Id
            , S.BillingPeriod
            , SA.QATMOperations
            , SA.QBrandOperations
            , SA.QPurchases
            , SA.TotalPurchases
            , SA.QWithdrawals
            , SA.TotalWithdrawals
        FROM dbo.SubAccountState SA
        INNER JOIN dbo.AccountState S
            ON SA.IdAccountState = S.Id
			
		--Insert in EventLog table
		INSERT dbo.EventLog(
			[LogDescription]
			, [PostIdUser]
			, [PostIp]
			, [PostTime])
		VALUES (
			@LogDescription
			, @postIdUser
			, @inPostIp
			, GETDATE()
			);
    END TRY
    BEGIN CATCH
        INSERT INTO dbo.DBErrors	VALUES (
            SUSER_SNAME(),
            ERROR_NUMBER(),
            ERROR_STATE(),
            ERROR_SEVERITY(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            ERROR_MESSAGE(),
            GETDATE()
        );

        Set @outResultCode=50009;                   -- Error code
    END CATCH
	SET NOCOUNT OFF;
END;