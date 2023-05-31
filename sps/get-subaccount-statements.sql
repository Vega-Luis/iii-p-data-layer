-- SP
-- Gets the subaccountStatements from a selected physical card
CREATE   PROCEDURE [dbo].[GetSubAccountStatements]
	@inPhysicalCardCode VARCHAR(16)
	, @inUsername VARCHAR(16)
	, @inPostIp VARCHAR(64)
	, @outResultCode INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		DECLARE
			@PostUserId INT
			, @LogDescription VARCHAR(256) = 
                        '{Action Type = Get subaccount statements '
						+ 'Description = ' 
						+ @inPhysicalCardCode + '}'

		DECLARE @postIdUser INT;
        SET @outResultCode = 0;                     -- No error code

        SELECT
            SA.Id
            , CAST(S.BillingPeriod AS VARCHAR(16)) AS BillingPeriod
            , SA.QATMOperations
            , SA.QBrandOperations
            , SA.QPurchases
            , SA.TotalPurchases
            , SA.QWithdrawals
            , SA.TotalWithdrawals
        FROM dbo.SubAccountState SA
        INNER JOIN dbo.AccountState S
            ON SA.IdAccountState = S.Id
        INNER JOIN dbo.PhysicalCard PC
            ON PC.IdCreditCardAccount = SA.IdAdditionalAccount
        AND PC.Code = @inPhysicalCardCode
        ORDER BY S.BillingPeriod DESC
			
		SELECT @PostUserId = U.Id
		FROM dbo.[User] U
		WHERE U.[Username] = @inUsername;
		--Insert in EventLog table
		INSERT dbo.EventLog(
			[LogDescription]
			, [PostIdUser]
			, [PostIp]
			, [PostTime])
		VALUES (
			@LogDescription
			, @PostUserId
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