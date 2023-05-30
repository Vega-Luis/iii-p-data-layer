-- SP
-- Show Physical Card

CREATE PROCEDURE dbo.ShowPhysicalCard
	@inUserName VARCHAR(16)
    , @inPostIp VARCHAR(16)
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
		DECLARE @CodeTF VARCHAR(16)
		DECLARE @CardStatus VARCHAR(16)
		DECLARE @AccountType VARCHAR(8)
		DECLARE @ExpirationDate DATE

        DECLARE @VALID_CARD VARCHAR(8) = 'Activa'
        DECLARE @INVALID_CARD VARCHAR(8) = 'Vencida'

        DECLARE @MASTER VARCHAR(8) = 'Maestra'
        DECLARE @ADITIONAL VARCHAR(16) = 'Adicional'

		SET @outResultCode = 0;

        SELECT @IdPhysicalCard = PC.Id
                , @CodeTF = PC.Code
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
                SET @CardStatus = @INVALID_CARD
            END
        ELSE
            BEGIN
                SET @CardStatus = @VALID_CARD
            END

        IF @IsMaster = 1
            BEGIN 
                SET @AccountType = @MASTER
            END
        ELSE
            BEGIN
                SET @AccountType = @ADITIONAL
            END

        SET @ExpirationDate = DATEFROMPARTS(@ExpirationYear, @ExpirationMonth, 30)

        SELECT 
			@IdPhysicalCard AS 'Id'
			, @CodeTF AS 'CardCode'
			, @CardStatus AS 'AccountStatus'
			, @AccountType AS 'AccountType'
			, @ExpirationDate AS 'ExpirationDate'

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