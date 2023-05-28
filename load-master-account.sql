-- Begin Master account insertion
	DELETE @InputMasterAccount

	INSERT INTO @InputMasterAccount(
		Code
		, [CTMType]
		, [CreditLimit]
		, [Value]
	)
	SELECT
		CTM.Item.value('@Codigo', 'INT')
		, CTM.Item.value('@TipoCTM', 'VARCHAR(16)')
		, CTM.Item.value('@LimiteCredito', 'MONEY')
		, CTM.Item.value('@TH', 'VARCHAR(16)')
	FROM @xmlData.nodes(
		'(root/fechaOperacion[@Fecha=sql:variable("@ActualDate")]/NTCM/NTCM)'
	)
	AS CTM(Item)

	-- Set Iteration floor and ceil
	SELECT
		@ActualIndex = MIN(CTM.Sec)
		, @LastIndex = MAX(CTM.Sec)
	FROM @InputMasterAccount CTM

	-- Setting minimum payment due date
	SELECT @MinPaymentDueDate = DATEADD(DAY, dbo.FNGetQDays(@IdAccountType,
					@Q_DAYS_TO_PAYMENT_RULE)
					, @ActualDate)
                    
	WHILE (@ActualIndex <= @LastIndex)
	BEGIN
		SELECT 
			@Code = IMA.Code
			, @CTMType = IMA.CTMType
			, @CreditLimit = IMA.CreditLimit
			, @Balance = IMA.CreditLimit
			, @Value = IMA.[Value]
		FROM @InputMasterAccount IMA
		WHERE IMA.Sec = @ActualIndex

		-- Get Master Account Type
		SELECT @IdAccountType = MAT.Id
		FROM dbo.AccountType MAT
		WHERE MAT.[Name] = @CTMType
	
		-- Get card holder Id
		SELECT @IdCardHolder = CH.Id
		FROM dbo.CardHolder CH
		WHERE CH.[Value] = @Value

		--Insertion in Credit card account
		INSERT INTO dbo.CreditCardAccount (
			Code
			, IsMaster
			, CreationDate
		)
		VALUES (
			@Code
			, @IsMaster
			, @ActualDate
		)

		SET @ActualAccountId = SCOPE_IDENTITY(); -- Get inserted account credit id

		INSERT INTO dbo.MasterAccount(
			IdCreditCardAccount
			, IdCardHolder
			, IdAccountType
			, CreditLimit
			, Balance
			, AccruedCurrentInterest
			, AccruedPenaultyInterest
		)
		VALUES(
			@ActualAccountId
			, @IdCardHolder
			, @IdAccountType
			, 0
		)

		INSERT INTO dbo.AccountState(
			IdMasterAccount
			, BillingPeriod
			, MinPaymentDueDate
		)
		VALUES(
			@ActualAccountId
			, @ActualDate
			, @MinPaymentDueDate
		)

		SET @ActualIndex = @ActualIndex + 1
	END
	-- End Master account insertion