-- Begin processing interest
SET @BalanceInterestCurrent = 0
SET @BalanceInterestPenaulty = 0
SELECT
    @ActualIndex = MIN(CTM.IdCreditCardAccount)
    , @LastIndex = MAX(CTM.IdCreditCardAccount)
FROM dbo.MasterAccount CTM

--Get Interest movement type
SELECT @CurrentMovementTypeId = CIMT.Id
FROM dbo.CurrentInterestMovementType CIMT
WHERE CIMT.[Action] = @ACTION_SUM

SELECT @PenaultyMovementTypeId = IMMT.Id
FROM dbo.InterestMoratorMovementType IMMT
WHERE IMMT.[Action] = @ACTION_SUB

--Get account state id and min due date
SELECT TOP 1  @MinPaymentDueDate = AST.MinPaymentDueDate
            , @PreviousMinPayment = AST.PreviousMinPayment
            , @TotalPaymentsBeforeDueDate =TotalPaymentsBeforeDueDate
FROM dbo.AccountState AST
WHERE AST.IdMasterAccount = @ActualIndex
ORDER BY BillingPeriod DESC

WHILE (@ActualIndex <= @LastIndex)
	BEGIN
		SELECT
			@MasterAccountId = MA.IdCreditCardAccount
			, @Balance = MA.Balance
			, @AccountTypeId = T.Id
		FROM dbo.MasterAccount MA
		INNER JOIN dbo.AccountType T
		ON T.Id = MA.IdAccountType
		AND MA.IdCreditCardAccount = @ActualIndex
        
    BEGIN TRY --TRY
        BEGIN TRANSACTION TDebitInterest
		IF @Balance > 0
		BEGIN
			SET @RateInterestCurrent = dbo.FNGetRateInterest(@AccountTypeId
												, @RATE_INTEREST_CURRENT)
			SET @AmountDebitInterestCurrent = @Balance /
											@RateInterestCurrent /100/30

			SET @BalanceInterestCurrent = @BalanceInterestCurrent +
										@AmountDebitInterestCurrent
			--INSERT
			INSERT INTO dbo.CurrentInterestMovement(
			IdMasterAccount
			, IdCurrentMovementType
			, [Date]
			, Amount
			, NewCurrentAccruedInterest
			)
			VALUES(
				@MasterAccountId
				, @CurrentMovementTypeId
				, @ActualDate
				, @AmountDebitInterestCurrent
				, @BalanceInterestCurrent
			)
		END

		IF @ActualDate > @MinPaymentDueDate
		AND @TotalPaymentsBeforeDueDate < @PreviousMinPayment
		AND DATEPART(dw, @ActualDate) != 1
		BEGIN
			SET @RateInterestMorator = dbo.FNGetRateInterest(@AccountTypeId
												, @RATE_INTEREST_MORATOR)
			SET @AmountPaymentMinimumPenaulty = @PreviousMinPayment - 
												@TotalPaymentsBeforeDueDate

			SET @AccruedDebitPenaultyInterest = @AmountPaymentMinimumPenaulty /
												@RateInterestMorator /100/30

			SET @BalanceInterestPenaulty = @BalanceInterestPenaulty +
										@AccruedDebitPenaultyInterest
			--Insert
			INSERT INTO dbo.InterestMoratorMovement(
			IdMasterAccount
			, IdInterestMoratorMovementType
			, [Date]
			, Amount
			, NewAccruedInterestMorator
			)
			VALUES(
				@MasterAccountId
				, @PenaultyMovementTypeId
				, @ActualDate
				, @AccruedDebitPenaultyInterest
				, @BalanceInterestPenaulty
			)
		END
		--UPDATE
		UPDATE dbo.MasterAccount 
		SET  AccruedCurrentInterest = AccruedCurrentInterest + @BalanceInterestCurrent
			, AccruedPenaultyInterest = AccruedPenaultyInterest + @BalanceInterestPenaulty
		WHERE IdCreditCardAccount = @MasterAccountId

        COMMIT TRANSACTION TDebitInterest
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
    --Counter interest
    SET @ActualIndex = @ActualIndex + 1
END