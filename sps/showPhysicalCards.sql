CREATE PROCEDURE [dbo].[ShowPhysicalCard]
	@inUsername VARCHAR(16)
	, @inPostIp VARCHAR(16)
	, @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        DECLARE @LogDescription VARCHAR(256) = 
                        '{Action Type = Get Physical cards '
						+ 'Description = ' 
						+ @inUsername + '}'
		DECLARE
			@CARDHOLDER_USER_TYPE VARCHAR(16) = 'Targeta Habiente'
			, @PostUserId INT
			, @IdCreditCardAccount INT
			, @IdCardHolder INT
			, @IdCardHolderUserType INT;

		-- Getting user type Id
		SELECT @IdCardHolderUserType = UT.Id
		FROM dbo.UserType UT
			WHERE UT.[Name] = @CARDHOLDER_USER_TYPE

		SELECT @IdCardHolder = U.Id
		FROM dbo.[User] U
		WHERE U.Username = @inUsername
		AND U.IdUserType = @IdCardHolderUserType

		-- Case the user is administrator
		IF @IdCardHolder IS NULL
		BEGIN
			SELECT
				PC.Id
				, PC.Code AS CardCode
				, IIF(PC.IdInvalidationMotive IS NOT NULL, 'Inactiva', 'Activa') AS AccountStatus
				, IIF(CCA.IsMaster = 1, 'Cuenta Maestra', 'Cuenta Adicional') AS AccountType
				, (CAST(PC.ExpirationYear AS VARCHAR(4)) + '-'
								+ CAST(PC.ExpirationMonth AS VARCHAR(2))) AS ExpirationDate
			FROM dbo.PhysicalCard PC
			INNER JOIN dbo.CreditCardAccount CCA
				ON PC.IdCreditCardAccount = CCA.Id
		END;
		ELSE 
		BEGIN
			-- Case the user is an master account card holder
			IF EXISTS (SELECT 1 FROM dbo.MasterAccount MA WHERE MA.IdCardHolder = @IdCardHolder)
			BEGIN
				SELECT
					PC.Id
					, PC.Code AS CardCode
					, IIF(PC.IdInvalidationMotive IS NOT NULL, 'Inactiva', 'Activa') AS AccountStatus
					, IIF(CCA.IsMaster = 1, 'Cuenta Maestra', 'Cuenta Adicional') AS AccountType
					, (CAST(PC.ExpirationYear AS VARCHAR(4)) + '-'
								+ CAST(PC.ExpirationMonth AS VARCHAR(2))) AS ExpirationDate
				FROM dbo.PhysicalCard PC
				INNER JOIN dbo.CreditCardAccount CCA
					ON PC.IdCreditCardAccount = CCA.Id
				INNER JOIN dbo.MasterAccount MA
					ON MA.IdCreditCardAccount = CCA.Id
				AND MA.IdCardHolder = @IdCardHolder
				INNER JOIN dbo.AdditionalAccount AA
					ON AA.IdMasterAccount = CCA.Id
			END
			-- Case the user is a additional account card holder
			ELSE
			BEGIN
				SELECT
					PC.Id
					, PC.Code AS CardCode
					, IIF(PC.IdInvalidationMotive IS NOT NULL, 'Inactiva', 'Activa') AS AccountStatus
					, IIF(CCA.IsMaster = 1, 'Cuenta Maestra', 'Cuenta Adicional') AS AccountType
					, (CAST(PC.ExpirationYear AS VARCHAR(4)) + '-'
								+ CAST(PC.ExpirationMonth AS VARCHAR(2))) AS ExpirationDate
				FROM dbo.PhysicalCard PC
				INNER JOIN dbo.CreditCardAccount CCA
					ON PC.IdCreditCardAccount = CCA.Id
				INNER JOIN dbo.AdditionalAccount AA
					ON AA.IdCreditCardAccount = CCA.Id
				AND AA.IdCardHolder = @IdCardHolder
			END;
		END;


				--Select Id from ArticleType
		SELECT @PostUserId = U.Id
		FROM dbo.[User] U
		WHERE U.[Username] = @inUsername;
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