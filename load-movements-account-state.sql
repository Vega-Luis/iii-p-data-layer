	-- Movement Insertion
	DELETE @InputMovement

	-- Preprocces movements from xml data
	INSERT INTO @InputMovement(
		[MovementName]
		, CodeTF
		, DateMovement
		, Amount
		, [DescriptionMovement]
		, [Reference]
		, [NewTFCode]
	)
	SELECT
		M.Item.value('@Nombre', 'VARCHAR(64)')
		, M.Item.value('@TF', 'VARCHAR(16)')
		, M.Item.value('@FechaMovimiento', 'DATE')
		, M.Item.value('@Monto', 'MONEY')
		, M.Item.value('@Descripcion', 'NVARCHAR(32)')
		, M.Item.value('@Referencia', 'NVARCHAR(16)')
		, M.Item.value('@NuevaTF', 'NVARCHAR(16)')
	FROM @xmlData.nodes(
		'(root/fechaOperacion[@Fecha=sql:variable("@ActualDate")]/Movimiento/Movimiento)'
	)
	AS M(Item)

	--Set iteration
	SELECT
		@ActualIndex = MIN(M.Sec)
		, @LastIndex = MAX(M.Sec)
	FROM @InputMovement M

	
	-- Beggins insertion iteration
	
	WHILE (@ActualIndex <= @LastIndex)
	BEGIN
		SET @TotalPurchases = 0;
		SET @QPurchases = 0;
		SET @TotalDebits = 0;
		SET @QDebits = 0;
		SET @QBrandOperations = 0;
		SET @TotalWithdrawals = 0;
		SET @QWithdrawals = 0;
		SET @QATMOperations = 0;
		SET @CurrentBalance = 0;
		SET @TotalPaymentsDuringMonth = 0;
		SET @TotalPaymentsBeforeDueDate = 0;
		SET @QPaymentsDuringMonth = 0;
		SET @TotalCredits = 0;
		SET @QCredits = 0;

		--Reset AmountDebitInterestCurrent
		SET @AmountDebitInterestCurrent = 0
		
		-- Obtains @InputMovement record in position @ActualIndex
		SELECT
			@MovementName = IMO.MovementName
			, @CodeTF = IMO.CodeTF
			, @DateMovement = IMO.DateMovement
			, @Amount = IMO.Amount
			, @DescriptionMovement = IMO.DescriptionMovement
			, @Reference = IMO.Reference
			, @NewTFCode = IMO.NewTFCode
		FROM @InputMovement IMO
		WHERE IMO.Sec = @ActualIndex

		--Get Physical card, Get Expiration date
		SELECT
			@IdPhysicalCard = PC.Id
			, @IdCreditCardAccount = PC.IdCreditCardAccount
			, @ExpirationYear = PC.ExpirationYear
			, @ExpirationMonth = PC.ExpirationMonth		
		FROM dbo.PhysicalCard PC
		WHERE PC.Code = @CodeTF

		-- Get Master account Id
		-- If the creditCardAccount is additional maps his master
		SELECT @MasterAccountId = IIF (
			(
			SELECT CAA.IsMaster
			FROM dbo.CreditCardAccount CAA
			WHERE CAA.Id = @IdCreditCardAccount
			) = 1
			, @IdCreditCardAccount
			, (
			SELECT AA.IdMasterAccount
			FROM dbo.AdditionalAccount AA
			WHERE AA.IdCreditCardAccount = @IdCreditCardAccount
			)
		)
		
		--Get movement type hay una funcion
		SET @IdMovementType = dbo.FNGetMovementTypeId(@MovementName)

		--Get account state id and min due date
		SELECT TOP 1 @IdAccountState = AST.Id
					, @MinPaymentDueDate = AST.MinPaymentDueDate
					, @PreviousMinPayment = AST.PreviousMinPayment
					, @TotalPaymentsBeforeDueDate =TotalPaymentsBeforeDueDate
		FROM dbo.AccountState AST
		WHERE AST.IdMasterAccount = @MasterAccountId
		ORDER BY BillingPeriod DESC

		--Get Action
		SELECT @Action = MT.[Name]
		FROM dbo.MovementType MT
		WHERE MT.Id = @IdMovementType

		--Get Balance
		SELECT @Balance = MA.Balance
				, @AccountTypeId = ATY.Id
		FROM dbo.MasterAccount MA
		INNER JOIN dbo.AccountType ATY
		ON ATY.Id = MA.IdAccountType
		WHERE MA.IdCreditCardAccount = @MasterAccountId


		SET @InvalidationMotiveId = 1
		-- Preprocess updates
		IF @MovementName = 'Compra'
			BEGIN 
				SET @TotalPurchases = @TotalPurchases + @Amount
				SET @QPurchases = @QPurchases + 1
				SET @TotalDebits = @TotalDebits + @Amount
				SET @QDebits = @QDebits + 1
			END
		IF @MovementName = 'Retiro en Ventana'
			BEGIN 
				SET @QBrandOperations = @QBrandOperations + 1
				SET @TotalWithdrawals = @TotalWithdrawals + @Amount
				SET @QWithdrawals = @QWithdrawals + 1
				SET @TotalDebits = @TotalDebits + @Amount
				SET @QDebits = @QDebits + 1
			END
		IF @MovementName = 'Retiro en ATM'
			BEGIN 
				SET @QATMOperations = @QATMOperations + 1
				SET @TotalWithdrawals = @TotalWithdrawals + @Amount
				SET @QWithdrawals = @QWithdrawals + 1
				SET @TotalDebits = @TotalDebits + @Amount
				SET @QDebits = @QDebits + 1
			END
		IF @MovementName = 'Pago en ATM'
			BEGIN 
				SET @QATMOperations = @QATMOperations + 1
				SET @CurrentBalance = @CurrentBalance + @Amount
				SET @TotalPaymentsDuringMonth = @TotalPaymentsDuringMonth + @Amount
				SET @TotalPaymentsBeforeDueDate = @TotalPaymentsBeforeDueDate + 
						CASE WHEN @MinPaymentDueDate < @ActualDate THEN @Amount ELSE 0 END
				SET @QPaymentsDuringMonth = @QPaymentsDuringMonth + 1
				SET @TotalCredits = @TotalCredits + @Amount
				SET @QCredits = @QCredits + 1
			END
		IF @MovementName = 'Pago en Ventana'
			BEGIN 
				SET @QBrandOperations = @QBrandOperations + 1
				SET @CurrentBalance = @CurrentBalance + @Amount
				SET @TotalPaymentsDuringMonth = @TotalPaymentsDuringMonth + @Amount
				SET @TotalPaymentsBeforeDueDate = @TotalPaymentsBeforeDueDate + 
						CASE WHEN @MinPaymentDueDate < @ActualDate THEN @Amount ELSE 0 END
				SET @QPaymentsDuringMonth = @QPaymentsDuringMonth + 1
				SET @TotalCredits = @TotalCredits + @Amount
				SET @QCredits = @QCredits + 1
			END
		IF @MovementName = 'Pago en Línea'
			BEGIN 
				SET @CurrentBalance = @CurrentBalance + @Amount
				SET @TotalPaymentsDuringMonth = @TotalPaymentsDuringMonth + @Amount
				SET @QPaymentsDuringMonth = @QPaymentsDuringMonth + 1
				SET @TotalPaymentsBeforeDueDate = @TotalPaymentsBeforeDueDate + 
						CASE WHEN @MinPaymentDueDate < @ActualDate THEN @Amount ELSE 0 END
			END

		-- If is an Additional account
		-- get IdSubAccountState
		SELECT @IdSubAccountState = SAS.Id
		FROM dbo.SubAccountState SAS
		WHERE SAS.IdAccountState = @IdAccountState

		IF @IsMaster = 0
		BEGIN
			IF @MovementName = 'Compra'
			BEGIN 
				SET @TotalPurchases = @TotalPurchases + @Amount
				SET @QPurchases = @QPurchases + 1
				SET @TotalDebits = @TotalDebits + @Amount
			END
			IF @MovementName = 'Retiro en Ventana'
			BEGIN 
				SET @QBrandOperations = @QBrandOperations + 1
				SET @TotalWithdrawals = @TotalWithdrawals + @Amount
				SET @QWithdrawals = @QWithdrawals + 1
				SET @TotalDebits = @TotalDebits + @Amount

			END
			IF @MovementName = 'Retiro en ATM'
			BEGIN 
				SET @QATMOperations = @QATMOperations + 1
				SET @TotalWithdrawals = @TotalWithdrawals + @Amount
				SET @QWithdrawals = @QWithdrawals + 1
				SET @TotalDebits = @TotalDebits + @Amount
			END
			-- For new TF additional account
			IF @MovementName = @MOVEMENT_TYPE_RECOVERY_LOST 
			OR @MovementName = @MOVEMENT_TYPE_RECOVERY_THEFT
				BEGIN
					SET @NewYear = DATEPART(YEAR, DATEADD(YEAR, 1, @ActualDate));
					SET @NewMonth = DATEPART(MONTH, @ActualDate);
					SET @NewCVV = CAST((RAND() * 9000) + 1000 AS INT);
					SET @MonetaryAmountPC = dbo.FNGetMonetaryAmount(@AccountTypeId
																	, @REPLACEMENT_FEE_CTA_RULE)
					SET @TotalDebits = @TotalDebits + @MonetaryAmountPC
				END
			IF @MovementName = @MOVEMENT_TYPE_RENEWAL_TF
				BEGIN
					SET @NewYear = DATEPART(YEAR, DATEADD(YEAR, 1, @ActualDate));
					SET @NewMonth = DATEPART(MONTH, @ActualDate);
					SET @NewCVV = CAST((RAND() * 9000) + 1000 AS INT);
					SET @MonetaryAmountPC = dbo.FNGetMonetaryAmount(@AccountTypeId
																	, @RENEWAL_FEE_CTA_RULE)
					SET @TotalDebits = @TotalDebits + @MonetaryAmountPC
				END
		END

		-- For new TF Master account
		IF @MovementName = @MOVEMENT_TYPE_RECOVERY_LOST 
			OR @MovementName = @MOVEMENT_TYPE_RECOVERY_THEFT
				BEGIN
					SET @NewYear = DATEPART(YEAR, DATEADD(YEAR, 1, @ActualDate));
					SET @NewMonth = DATEPART(MONTH, @ActualDate);
					SET @NewCVV = CAST((RAND() * 9000) + 1000 AS INT);
					SET @MonetaryAmountPC = dbo.FNGetMonetaryAmount(@AccountTypeId
																	, @REPLACEMENT_FEE_CTM_RULE)
					SET @TotalDebits = @TotalDebits + @MonetaryAmountPC
				END
			IF @MovementName = @MOVEMENT_TYPE_RENEWAL_TF
				BEGIN
					SET @NewYear = DATEPART(YEAR, DATEADD(YEAR, 1, @ActualDate));
					SET @NewMonth = DATEPART(MONTH, @ActualDate);
					SET @NewCVV = CAST((RAND() * 9000) + 1000 AS INT);
					SET @MonetaryAmountPC = dbo.FNGetMonetaryAmount(@AccountTypeId
																	, @RENEWAL_FEE_CTM_RULE)
					SET @TotalDebits = @TotalDebits + @MonetaryAmountPC
		END

		BEGIN TRY
		BEGIN TRANSACTION TProcessMovements
			IF @NewTFCode != ''
			BEGIN
				INSERT INTO dbo.PhysicalCard(
					IdCreditCardAccount
					, IdInvalidationMotive
					, Code
					, ExpirationYear
					, ExpirationMonth
					, CVV
					, CreationDate
				)
				VALUES(
					@IdCreditCardAccount
					, @InvalidationMotiveId
					, @NewTFCode
					, @ExpirationYear
					, @ExpirationMonth
					, @NewCVV
					, @ActualDate
				)
				UPDATE PC
				SET PC.IdInvalidationMotive = @InvalidationMotiveId
					, PC.InvalidationDate = @ActualDate
				FROM dbo.PhysicalCard PC
				WHERE PC.Code = @CodeTF
			END
			-- Suspecious movement insertion

			IF EXISTS(SELECT 1 FROM dbo.PhysicalCard PC
				WHERE PC.Code = @CodeTF
				AND PC.IdInvalidationMotive != NULL)
				BEGIN
				INSERT INTO dbo.SuspiciousMovement (
					IdMasterAccount,
					IdPhysicalCard,
					[Date],
					Amount,
					[Description],
					[Reference]
				)
				VALUES(
					@MasterAccountId,
					@IdPhysicalCard,
					@DateMovement,
					@Amount,
					@DescriptionMovement,
					@Reference
					)
				END;
			--Movements insertion
			INSERT INTO dbo.Movement(
				IdMasterAccount
				, IdMovementType
				, IdAccountState
				, IdPhysicalCard
				, [Date]
				, Amount
				, [Description]
				, [Reference]
				, NewBalance
			)
			VALUES(
				@MasterAccountId
				, @IdMovementType
				, @IdAccountState
				, @IdPhysicalCard
				, @DateMovement
				, @Amount
				, @DescriptionMovement
				, @Reference
				, @NewBalance
			)
			
			-- UPDATE PROCESS
			
			SET @Balance = dbo.FNCalculateNewBalance(@Amount, @Action, @Balance)

			UPDATE dbo.MasterAccount 
			SET Balance = @Balance
			WHERE IdCreditCardAccount = @MasterAccountId

			UPDATE dbo.Movement
			SET NewBalance = @Balance
			WHERE IdMasterAccount = @MasterAccountId

			-- Always execute
			UPDATE dbo.AccountState
			SET  TotalPurchases = TotalPurchases + @TotalPurchases 
				, QPurchases = QPurchases + @QPurchases 
				, TotalDebits = TotalDebits + @TotalDebits
				, QDebits = QDebits + @QDebits
				, QBrandOperations = QBrandOperations + @QBrandOperations
				, TotalWithdrawals = TotalWithdrawals + @TotalWithdrawals
				, QWithdrawals = QWithdrawals + @QWithdrawals
				, QATMOperations = QATMOperations + @QATMOperations
				, CurrentBalance = CurrentBalance + @CurrentBalance
				, TotalPaymentsDuringMonth = TotalPaymentsDuringMonth + @TotalPaymentsDuringMonth
				, TotalPaymentsBeforeDueDate = TotalPaymentsBeforeDueDate + @TotalPaymentsBeforeDueDate
				, QPaymentsDuringMonth = QPaymentsDuringMonth + @QPaymentsDuringMonth
				, TotalCredits = TotalCredits + @TotalCredits
				, QCredits = QCredits + @QCredits
			WHERE Id = @IdAccountState

			--UPDATE SubAccount State
			UPDATE dbo.SubAccountState
			SET TotalPurchases = TotalPurchases + @TotalPurchases
				, QPurchases = QPurchases + @QPurchases
				, TotalDebits = TotalDebits + @TotalDebits
				, QBrandOperations = QBrandOperations + @QBrandOperations
				, TotalWithdrawals = TotalWithdrawals + @TotalWithdrawals
				, QWithdrawals = QWithdrawals + @QWithdrawals
				, QATMOperations = QATMOperations + @QATMOperations
			WHERE Id = @IdSubAccountState
			AND @IsMaster = 0
			
			--COMMIT
			COMMIT TRANSACTION TProcessMovements
		END TRY
		BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK;
		END;
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
		END CATCH
		SET NOCOUNT OFF
		--Counter
		SET @ActualIndex = @ActualIndex + 1
	END
	-- End Movement insertion
