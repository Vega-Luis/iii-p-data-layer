-- Preprocessing input physical cards

	DELETE @InputPhysicalCard

	INSERT INTO @InputPhysicalCard (
		CardCode
		, CreditCardAccountCode
		, ExpirationDateString
		, CVV
	)
	SELECT
		T.Item.value('@Codigo', 'VARCHAR(16)')
		, T.Item.value('@TCAsociada', 'INT')
		, T.Item.value('@FechaVencimiento', 'VARCHAR(8)')
		, T.Item.value('@CCV', 'INT')
	FROM @xmlData.nodes(
		'(root/fechaOperacion[@Fecha=sql:variable("@ActualDate")]/NTF/NTF)'
		)
	AS T(Item)

	-- Set Iteration floor and ceil
	SELECT
		@ActualIndex = MIN(IPC.Sec)
		, @LastIndex = MAX(IPC.Sec)
	FROM @InputPhysicalCard IPC
	
	-- begins iteration, inserting into physical card table
	WHILE (@ActualIndex <= @LastIndex)
	BEGIN
		SELECT
			@CardCode = IPC.CardCode
			, @CreditCardAccountCode = IPC.CreditCardAccountCode
			, @ExpirationDateString = IPC.ExpirationDateString
			, @CVV = IPC.CVV
		FROM @InputPhysicalCard IPC
		WHERE IPC.Sec = @ActualIndex

		-- Getting credit card account id
		SELECT @CreditCardAccountId = CCA.Id
		FROM dbo.CreditCardAccount CCA
		WHERE CCA.Code = @CreditCardAccountCode

		SELECT
			@ExpirationMonth = CAST(SUBSTRING(@ExpirationDateString, 1, CHARINDEX('/', @ExpirationDateString) - 1) AS INT)
			, @ExpirationYear = CAST(SUBSTRING(@ExpirationDateString, CHARINDEX('/', @ExpirationDateString) + 1, 4) AS INT);
		
		INSERT INTO dbo.PhysicalCard (
			IdCreditCardAccount
			, Code
			, ExpirationYear
			, ExpirationMonth
			, CVV
			, CreationDate
		)
		VALUES (
			@CreditCardAccountId
			, @CardCode
			, @ExpirationYear
			, @ExpirationMonth
			, @CVV
			, @ActualDate
		)
		SET @ActualIndex = @ActualIndex + 1
	END