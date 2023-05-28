-- Preprocess input additional accounts
	DELETE @InputAdditionalAccount
	INSERT INTO @InputAdditionalAccount (
		MasterAccountCode
		, AdditionalAccountCode
		, IdentificationValue
	)
	SELECT
		T.Item.value('@CodigoTCM', 'INT')
		, T.Item.value('@CodigoTCA', 'INT')
		, T.Item.value('@TH', 'VARCHAR(16)')
	FROM @xmlData.nodes(
		'(root/fechaOperacion[@Fecha=sql:variable("@ActualDate")]/NTCA/NTCA)'
		)
	AS T(Item)

	-- Set Iteration floor and ceil
	SELECT
		@ActualIndex = MIN(IAA.Sec)
		, @LastIndex = MAX(IAA.Sec)
	FROM @InputAdditionalAccount IAA
	
	-- begins iteration, inserting input additional accounts
	WHILE(@ActualIndex <= @LastIndex)
	BEGIN
		SELECT
			@MasterAccountCode = IAA.MasterAccountCode
			, @AdditionalAccountCode = IAA.AdditionalAccountCode
			, @IdentificationValue = IAA.IdentificationValue
		FROM @InputAdditionalAccount IAA
		WHERE IAA.Sec = @ActualIndex

		-- Get masterAccount Id
		SELECT @MasterAccountId = CCA.Id
		FROM dbo.CreditCardAccount CCA
		WHERE CCA.Code = @MasterAccountCode

		-- Get card holder Id
		SELECT @CardHolderId = CH.Id
		FROM dbo.CardHolder CH
		WHERE CH.Value = @IdentificationValue
		
		-- Get account state id
		SELECT TOP 1
			@AccountStateId = A.ID
		FROM dbo.AccountState A
		WHERE A.IdMasterAccount = @MasterAccountId
		ORDER BY BillingPeriod DESC

		INSERT INTO dbo.CreditCardAccount (
			Code
			, IsMaster
			, CreationDate
		)
		VALUES (
			@AdditionalAccountCode
			, @IS_ADDITIONAL_ACCOUNT
			, @ActualDate
		)

		SET @ActualAccountId = SCOPE_IDENTITY(); -- Get inserted account credit id

		INSERT INTO dbo.AdditionalAccount (
			IdCreditCardAccount
			, IdCardHolder
			, IdMasterAccount
		)
		VALUES (
			@ActualAccountId
			, @CardHolderId
			, @MasterAccountId
		)
		

		-- Creating sub account state for additional account
		-- The other attributes start in 0 by default
		INSERT INTO dbo.SubAccountState (
			IdAdditionalAccount
			, IdAccountState
		)
		VALUES (
			@ActualAccountId
			, @AccountStateId
		)

		SET @ActualIndex = @ActualIndex + 1
	END
	-- ends additional account insertion