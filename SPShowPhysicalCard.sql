-- SP
-- Show Physical Card

CREATE PROCEDURE dbo.ShowPhysicalCard
	@inUserName VARCHAR(16)
    , @inPostIp VARCHAR(16)
	, @outCodeTF VARCHAR(16) OUTPUT
    , @outCardStatus VARCHAR(8) OUTPUT
    , @outAccountType VARCHAR(8) OUTPUT
    , @outExpirationDate DATE OUTPUT
	, @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        DECLARE @LogDescription VARCHAR(256) = 
                        '{Action Type = Get Physical cards '
						+ 'Description = ' 
						+ @inUserName + '}'
		DECLARE @IdPhysicalCard INT
        DECLARE @IdInvalidationMotive INT
        DECLARE @IsMaster BIT
        DECLARE @ExpirationYear INT
        DECLARE @ExpirationMonth INT
		DECLARE @PostIdUser INT

        DECLARE @VALID_CARD VARCHAR(8) = 'Activa'
        DECLARE @INVALID_CARD VARCHAR(8) = 'Vencida'

        DECLARE @MASTER VARCHAR(8) = 'Maestra'
        DECLARE @ADITIONAL VARCHAR(16) = 'Adicional'

		SET @outResultCode = 0;

        SELECT @IdPhysicalCard = PC.Id
                , @outCodeTF = PC.Code
                , @IdInvalidationMotive = PC.IdInvalidationMotive
                , @IsMaster = CCA.IsMaster
                , @ExpirationYear = PC.ExpirationYear
                , @ExpirationMonth = PC.ExpirationMonth
                , @PostIdUser = U.Id
        FROM dbo.PhysicalCard PC
        INNER JOIN dbo.CreditCardAccount CCA
        ON CCA.Id = PC.IdCreditCardAccount
        INNER JOIN dbo.MasterAccount MA
        ON MA.IdCreditCardAccount = CCA.Id
        INNER JOIN dbo.CardHolder CH
        ON CH.Id = MA.IdCardHolder
		INNER JOIN dbo.[User] U
		ON U.Id = CH.Id
        AND U.[Username] = @inUserName;


        IF @IdInvalidationMotive != NULL
            BEGIN
                SET @outCardStatus = @INVALID_CARD
            END
        ELSE
            BEGIN
                SET @outCardStatus = @VALID_CARD
            END

        IF @IsMaster = 1
            BEGIN 
                SET @outAccountType = @MASTER
            END
        ELSE
            BEGIN
                SET @outAccountType = @ADITIONAL
            END

        SET @outExpirationDate = DATEFROMPARTS(@ExpirationYear, @ExpirationMonth, 30)

        SELECT 
			@IdPhysicalCard
			, @outCodeTF 
			, @outCardStatus 
			, @outAccountType 
			, @outExpirationDate 
			, @outResultCode

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