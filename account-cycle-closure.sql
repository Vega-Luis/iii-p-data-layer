		DECLARE
    	@MOVEMENT_TYPE_ACCRUED_INTEREST VARCHAR(64) = 'Intereses Corrientes sobre Saldo'
		, @MOVEMENT_TYPE_PENALTY_INTEREST VARCHAR(64) = 'Intereses Moratorios Pago no Realizado'
		, @MOVEMENT_TYPE_SERVICES  VARCHAR(64) = 'Cargos por Servicio'
		, @MOVEMENT_TYPE_OVER_ATM VARCHAR(64) = 'Cargos por Multa Exceso Uso ATM'
		, @MOVEMENT_TYPE_OVER_BRAND VARCHAR (64) = 'Cargos por Multa Exceso Uso Ventana'
        , @MOVEMENT_TYPE_INTEREST_REDEMPTION VARCHAR(64) = 'Credito por Redencion'
		, @MASTER_ACCOUNT_SERVICES_RULE VARCHAR(64) = 'Cargos Servicio Mensual CTM'
		, @ADDITIONAL_ACCOUNT_SERVICES_RULE VARCHAR(64) = 'Cargos Servicio Mensual CTA'
		, @FRAUD_INSURANCE_RULE VARCHAR(64) = 'Cargo Seguro Contra Fraudes'
		, @OVER_ATM_OPERATIONS_RULE VARCHAR(64) = 'Multa exceso de operaciones ATM'
		, @OVER_BRAND_OPERATIONS_RULE VARCHAR(64) = 'Multa exceso de operaciones Ventanilla'
		, @ATM_OPERATIONS_LIMIT_RULE VARCHAR(64) = 'Cantidad de opraciones en ATM'
		, @BRAND_OPERATIONS_LIMIT_RULE VARCHAR(64) = 'Cantidad de operacion en Ventanilla'
        , @Q_DAYS_TO_PAYMENT_RULE VARCHAR(64) = 'Cantidad de dias para pago saldo de contado'
		, @REFERENCE VARCHAR(64) = 'Closing Account Statement'
		, @IdAccountState INT
		, @IdMasterAccount INT
		, @CreditCardCreationDate DATE
		, @StatementBalance MONEY -- Account statement balance
		, @PreviousMinPayment MONEY
		, @BillingPeriod DATE
		, @MinPaymentDueDate DATE
		, @LatePaymentInterest FLOAT
		, @QATMOperations INT
		, @QBrandOperations INT
		, @TotalPaymentsBeforeDueDate MONEY
		, @MasterAccountFee MONEY
		, @AdditionalAccountFee MONEY
		, @FraudInsuranceFee MONEY
		, @ATMOverOperationsFEE MONEY
		, @BrandOverOperationsFee MONEY
		, @IdMovementType INT
		, @QAdditionalAccounts INT
		, @ATMOperationsLimit INT
		, @BrandOperationsLimit INT
		, @IdPhysicalCard INT
		, @CurrentBalance MONEY -- Account current balance
		, @AcruedCurrentInterest MONEY
		, @AccruedPenaltyInterest MONEY
        , @QpaymentInstallments INT = 10 -- Remember to change value
        , @CurrentInterestMovementTypeId INT
        , @PenaltyInterestMovementTypeId INT
		;

        -- Obtain interest movememt types id
        SELECT @CurrentInterestMovementTypeId = MT.Id
        FROM dbo.CurrentInterestMovementType MT
        WHERE MT.[Name] = @MOVEMENT_TYPE_INTEREST_REDEMPTION

        SELECT @PenaltyInterestMovementTypeId = MT.Id
        FROM dbo.InterestMoratorMovementType MT
        WHERE MT.[Name] = @MOVEMENT_TYPE_INTEREST_REDEMPTION

	-- Processing Account staments
	-- Account Statements that are in closing date
	DECLARE @ClosingDateAccountState TABLE (
		Sec INT IDENTITY(1,1)
		, IdAccountState INT
		, IdMasterAccount INT
		, CreditCardCreationDate DATE
		, StatementBalance MONEY
		, PreviousMinPayment MONEY
		, AccruedCurrentInterest FLOAT
		, LatePaymentInterest FLOAT
		, QATMOperations INT
		, QBrandOperations INT
		, TotalPaymentsBeforeDueDate MONEY
	)
	
	DELETE @ClosingDateAccountState
	-- Insert into temp table on date closing account states
	INSERT @ClosingDateAccountState
	SELECT
   		CS.Id
		, CS.IdMasterAccount
		, CCA.CreationDate
   		, CS.CurrentBalance
   		, CS.PreviousMinPayment
   		, CS.AccruedCurrentInterest
   		, CS.LatePaymentInterest
   		, CS.QATMOperations
   		, CS.QBrandOperations
   		, CS.TotalPaymentsBeforeDueDate
	FROM dbo.AccountState CS
    INNER JOIN dbo.CreditCardAccount CCA
	ON CCA.Id = CS.IdMasterAccount
	AND dbo.FNIsClosingDate(CCA.CreationDate, @ActualDate) = 1

	-- Obtaining loop index
	SELECT
		 @ActualIndex = MIN(CS.Sec)
		 , @LastIndex = MAX(CS.Sec)
	FROM @ClosingDateAccountState CS

	-- Go through every record
	WHILE (@ActualIndex <= @LastIndex)
	BEGIN
		BEGIN TRY
			-- GET AccountState records on actual index
			SELECT
				@IdAccountState = CS.IdAccountState
				, @IdMasterAccount = CS.IdMasterAccount
				, @StatementBalance = CS.StatementBalance
				, @PreviousMinPayment = CS.PreviousMinPayment
				, @QATMOperations = CS.QATMOperations
				, @QBrandOperations = CS.QBrandOperations
				, @TotalPaymentsBeforeDueDate = CS.TotalPaymentsBeforeDueDate
			FROM @ClosingDateAccountState CS

			-- New billing period date
			SELECT @BillingPeriod = DATEADD(DAY, 1, @ActualDate)

			-- Select the last Physical card
			SELECT TOP 1
				@IdPhysicalCard = PC.Id
			FROM dbo.PhysicalCard PC
			WHERE PC.IdCreditCardAccount = @IdMasterAccount
			ORDER BY PC.CreationDate DESC

			-- Get master account attributes
			SELECT
				@CurrentBalance = MA.Balance
				, @AcruedCurrentInterest = MA.AccruedCurrentInterest
				, @AccruedPenaltyInterest = MA.AccruedPenaultyInterest
			FROM dbo.MasterAccount MA
			WHERE MA.IdCreditCardAccount = @IdMasterAccount

			-- Get total additional accounts
			SELECT @QAdditionalAccountS = COUNT(AA.IdCreditCardAccount)
			FROM dbo.AdditionalAccount AA
			WHERE AA.IdMasterAccount = @IdMasterAccount

			-- Get account type id
			SELECT @IdAccountType = T.Id
			FROM dbo.AccountType T
			INNER JOIN dbo.MasterAccount M
				ON M.IdAccountType = T.Id

			-- Setting minimum payment due date
			SELECT @MinPaymentDueDate = DATEADD(DAY, dbo.FNGetQDays(@IdAccountType,
							@Q_DAYS_TO_PAYMENT_RULE)
							, @ActualDate)

			-- Getting master account service fee from business rule
			SET @MasterAccountFee = dbo.FNGetMonetaryAmount(@IdAccountType,
							@MASTER_ACCOUNT_SERVICES_RULE)

			-- Getting additional account service fee from business rule
			SET @AdditionalAccountFee = dbo.FNGetMonetaryAmount(@IdAccountType,
							@ADDITIONAL_ACCOUNT_SERVICES_RULE)

			SET @AdditionalAccountFee = @AdditionalAccountFee * @QAdditionalAccounts
			-- Getting insurance service fee from business rule

			SET @FraudInsuranceFee = dbo.FNGetMonetaryAmount(@IdAccountType,
							@FRAUD_INSURANCE_RULE)
								
			-- Getting over atm operations charge from business rule
			SET @ATMOverOperationsFEE = dbo.FNGetMonetaryAmount(@IdAccountType,
							@OVER_ATM_OPERATIONS_RULE)

			-- Getting over atm operations charge from business rule
			SET @BrandOverOperationsFee = dbo.FNGetMonetaryAmount(@IdAccountType,
							@OVER_BRAND_OPERATIONS_RULE)


			-- Movement redemption
			INSERT INTO dbo.InterestMoratorMovement(
				IdMasterAccount
				, IdInterestMoratorMovementType
				, [Date]
				, Amount
				, NewAccruedInterestMorator
			)
			VALUES (
				@IdMasterAccount
				, @PenaltyInterestMovementTypeId
				, @ActualDate
				, @AccruedPenaltyInterest
				, 0
			)

			INSERT INTO dbo.CurrentInterestMovement(
				IdMasterAccount
				, IdCurrentMovementType
				, [Date]
				, Amount
				, NewCurrentAccruedInterest
			)
			VALUES (
				@IdMasterAccount
				, @CurrentInterestMovementTypeId
				, @ActualDate
				, @AccruedPenaltyInterest
				, 0
			)
			-- The movement for accrued current interest is done
			-- only if the total payments before due date is not the statement balance
			IF @StatementBalance <= @TotalPaymentsBeforeDueDate
			BEGIN
				-- Current Interest Movement
				SET @IdMovementType = dbo.FNGetMovementTypeId(@MOVEMENT_TYPE_ACCRUED_INTEREST)
				SET @CurrentBalance = @CurrentBalance + @AccruedCurrentInterest
				INSERT INTO dbo.Movement (
					IdMasterAccount
					, IdMovementType
					, IdAccountState
					, IdPhysicalCard
					, [Description]
					, [Date]
					, Amount
					, Reference
					, NewBalance
				)
				VALUES (
						@IdMasterAccount
						, @IdMovementType
						, @IdAccountState
						, @IdPhysicalCard
						, @MOVEMENT_TYPE_ACCRUED_INTEREST   -- Movement description
						, @ActualDate
						, @AccruedCurrentInterest   -- Movement amount
						, @REFERENCE
						, @CurrentBalance
				)
			END; 

			-- Only if there is penaltyInterest
			IF @AccruedPenaltyInterest > 0
			BEGIN
			-- Penalty interest Movement
			SET @IdMovementType = dbo.FNGetMovementTypeId(@MOVEMENT_TYPE_PENALTY_INTEREST)
			SET @CurrentBalance = @CurrentBalance + @AccruedPenaltyInterest
				INSERT INTO dbo.Movement (
					IdMasterAccount
					, IdMovementType
					, IdAccountState
					, IdPhysicalCard
					, [Description]
					, [Date]
					, Amount
					, Reference
					, NewBalance
				)
				VALUES (
						@IdMasterAccount
						, @IdMovementType
						, @IdAccountState
						, @IdPhysicalCard
						, @MOVEMENT_TYPE_PENALTY_INTEREST   -- Movement description
						, @ActualDate
						, @AccruedPenaltyInterest -- Movement amount
						, @REFERENCE
						, @CurrentBalance
				)
			END;

			-- Gettting movement type id
			SET @IdMovementType = dbo.FNGetMovementTypeId(@MOVEMENT_TYPE_SERVICES)
			-- Master account service fee movement
			SET @CurrentBalance = @CurrentBalance + @MasterAccountFee
			INSERT INTO dbo.Movement (
				IdMasterAccount
				, IdMovementType
				, IdAccountState
				, IdPhysicalCard
				, [Description]
				, [Date]
				, Amount
				, Reference
				, NewBalance
			)
			VALUES (
				@IdMasterAccount
				, @IdMovementType
				, @IdAccountState
				, @IdPhysicalCard
				, @MASTER_ACCOUNT_SERVICES_RULE
				, @ActualDate
				, @MasterAccountFee     -- Movement amount
				, @REFERENCE
				, @CurrentBalance
			)

			-- Additional account service fee movement
			SET @CurrentBalance = @CurrentBalance + @AdditionalAccountFee
			INSERT INTO dbo.Movement (
				IdMasterAccount
				, IdMovementType
				, IdAccountState
				, IdPhysicalCard
				, [Description]
				, [Date]
				, Amount
				, Reference
				, NewBalance
			)
			VALUES (
				@IdMasterAccount
				, @IdMovementType
				, @IdAccountState
				, @IdPhysicalCard
				, @ADDITIONAL_ACCOUNT_SERVICES_RULE
				, @ActualDate
				, @AdditionalAccountFee     -- Movement amount
				, @REFERENCE
				, @CurrentBalance
			)

			-- Fraud insurance service fee movement
			SET @CurrentBalance = @CurrentBalance + @FraudInsuranceFee
			INSERT INTO dbo.Movement (
				IdMasterAccount
				, IdMovementType
				, IdAccountState
				, IdPhysicalCard
				, [Description]
				, [Date]
				, Amount
				, Reference
				, NewBalance
				)
			VALUES (
				@IdMasterAccount
				, @IdMovementType
				, @IdAccountState
				, @IdPhysicalCard
				, @FRAUD_INSURANCE_RULE
				, @ActualDate
				, @FraudInsuranceFee    -- Movement amount
				, @REFERENCE
				, @CurrentBalance
			)

			-- Over ATM operations movement
			IF @QATMOperations > dbo.FNGetOperationsAmount(@IdAccountType,
							@ATM_OPERATIONS_LIMIT_RULE)
			BEGIN
				-- Gettting movement type id
				SET @IdMovementType = dbo.FNGetMovementTypeId(@MOVEMENT_TYPE_OVER_ATM)
				-- Inserting over atm operations  charge movement
				SET @CurrentBalance = @CurrentBalance + @ATMOverOperationsFEE
				INSERT INTO dbo.Movement (
					IdMasterAccount
					, IdMovementType
					, IdAccountState
					, IdPhysicalCard
					, [Description]
					, [Date]
					, Amount
					, Reference
					, NewBalance
				)
				VALUES (
						@IdMasterAccount
						, @IdMovementType
						, @IdAccountState
						, @IdPhysicalCard
						, @OVER_BRAND_OPERATIONS_RULE
						, @ActualDate
						, @BrandOverOperationsFee   -- Movement amount
						, @REFERENCE
						, @CurrentBalance
				)
			END

			-- Over brand operations movement
			IF @QBrandOperations > dbo.FNGetOperationsAmount(@IdAccountType,
							@BRAND_OPERATIONS_LIMIT_RULE)
				BEGIN
				-- Gettting movement type id
				SET @IdMovementType = dbo.FNGetMovementTypeId(@MOVEMENT_TYPE_OVER_BRAND)
				-- Inserting fraud insurance servise fee movement
				SET @CurrentBalance = @CurrentBalance + @BrandOverOperationsFee
				INSERT INTO dbo.Movement (
					IdMasterAccount
					, IdMovementType
					, IdAccountState
					, IdPhysicalCard
					, [Description]
					, [Date]
					, Amount
					, Reference
					, NewBalance
				)
				VALUES (
					@IdMasterAccount
					, @IdMovementType
					, @IdAccountState
					, @IdPhysicalCard
					, @OVER_BRAND_OPERATIONS_RULE
					, @ActualDate
					, @BrandOverOperationsFee   -- Movement amount
					, @REFERENCE
					, @CurrentBalance
				)
			END


			-- Minimum payment
			SET @PreviousMinPayment = @CurrentBalance / @QpaymentInstallments 
							
			-- Inserting new Account State 
			INSERT INTO dbo.AccountState (
				IdMasterAccount
				, CurrentBalance    -- Statement balance
				, PreviousMinPayment
				, BillingPeriod
				, MinPaymentDueDate
				, AccruedCurrentInterest
				, LatePaymentInterest
			)
			VALUES (
				@IdMasterAccount
				, @CurrentBalance -- New statement balance
				, @PreviousMinPayment
				, @BillingPeriod 
				, @MinPaymentDueDate 
				, @AccruedCurrentInterest 
				, @AccruedPenaltyInterest
			)

			UPDATE MA
			SET
				MA.Balance = @CurrentBalance
				,  MA.AccruedCurrentInterest = 0
				, MA.AccruedPenaultyInterest = 0
			FROM dbo.MasterAccount MA
			WHERE MA.IdCreditCardAccount = @IdMasterAccount
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
		END CATCH

		SET @ActualIndex = @ActualIndex + 1
	END