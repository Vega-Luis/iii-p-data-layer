-- SP
-- Show Master account Statements

CREATE PROCEDURE dbo.ShowMasterAccountStatement
	@inTFCode VARCHAR(16)
    , @inPostIp VARCHAR(16)
	, @outMinPayment MONEY OUTPUT
    , @outActualBalance MONEY OUTPUT
    , @outCurrentInterest MONEY OUTPUT
    , @outPenaultyInterest DATE OUTPUT
    , @outQOperationsATM INT OUTPUT
    , @outQOperationsBrand INT OUTPUT
    , @outIdAccountStatement INT OUTPUT
	, @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @LogDescription VARCHAR(256) = 
                        '{Action Type = Get Master Account Statements '
						+ 'Description = ' 
						+ @inTFCode + '}'
        DECLARE @PostIdUser INT
		SET @outResultCode = 0; 

        SELECT AC.Id
			, AC.BillingPeriod
			, AC.PreviousMinPayment
			, AC.CurrentBalance
			, AC.AccruedCurrentInterest
			, AC.LatePaymentInterest
			, AC.QATMOperations
			, AC.QBrandOperations
		FROM dbo.AccountState AC
		INNER JOIN dbo.MasterAccount MA
		ON MA.IdCreditCardAccount = AC.IdMasterAccount
		INNER JOIN dbo.PhysicalCard PC
		ON PC.Code = @inTFCode

		SELECT @PostIdUser = U.Id
		FROM dbo.[User] U
		INNER JOIN dbo.CardHolder CH
		ON CH.Id = U.Id
		INNER JOIN dbo.MasterAccount MA
		ON MA.IdCardHolder = CH.Id
		INNER JOIN dbo.CreditCardAccount CA
		ON CA.Id = MA.IdCreditCardAccount
		INNER JOIN dbo.PhysicalCard PC
		ON PC.Code = @inTFCode

    -- Insert into eventLog table
    INSERT INTO dbo.EventLog
        VALUES (
        @LogDescription
        , @PostIdUser
        , @inPostIp
        , GETDATE()
        );
    END TRY
    BEGIN CATCH
		INSERT INTO dbo.DBErrors
			VALUES(
			SUSER_SNAME()
			, ERROR_NUMBER()
			, ERROR_STATE()
			, ERROR_SEVERITY()
			, ERROR_LINE()
			, ERROR_PROCEDURE()
			, ERROR_MESSAGE()
			, GETDATE()
			);
			SET @outResultCode = 50009;		-- Error result code
	END CATCH
	SET NOCOUNT OFF;
END;