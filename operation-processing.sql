-- Pricipal variables
DECLARE
	@xmlData XML
	, @ActualRecord INT
	, @LastRecord INT
	, @ActualDate DATE
	;

-- Iteration variables
DECLARE
	@ActualIndex INT
	, @LastIndex INT
	;

-- Card holder insertion variables
DECLARE
	@CardHolderName VARCHAR(64)
	, @DocumentTypeName VARCHAR(16)
	, @IdentificationValue VARCHAR(16) -- CardHolder identificacion document value
	, @Username VARCHAR(16)
	, @Password VARCHAR(16)
	, @CardHolderUserType INT
	, @ActualCardHolderId INT
	, @DocumentTypeId INT
	;

-- Getting card holder user type
SELECT @CardHolderUserType = UT.Id
FROM dbo.UserType UT
WHERE UT.[Name] = 'Targeta Habiente'

-- Master account insertion variables
DECLARE 
	@Code INT
	, @CreditLimit MONEY
	, @Balance MONEY
	, @IsMaster BIT = 1
	, @CTMType VARCHAR(16)
	, @Value VARCHAR(16)
	, @IdCreditCardAccount INT
	, @IdCardHolder INT
	, @IdAccountType INT
	, @IdAccountState INT
	, @AccruedCurrentInterest MONEY = 0
	, @AccruedPenaultyInterest MONEY = 0

Declare @InputMasterAccount TABLE(
	Sec INT IDENTITY(1,1)
	, Code INT
	, CTMType VARCHAR(16)
	, [CreditLimit] MONEY
	, [Value] VARCHAR(16)
);

-- Aditional account insertation variables
DECLARE
	@MasterAccountCode INT
	, @AdditionalAccountCode INT
	, @IS_ADDITIONAL_ACCOUNT INT = 0 -- Addtional account identifier
	, @ActualAccountId INT
	, @MasterAccountId INT
	, @CardHolderId INT
	;

DECLARE @InputAdditionalAccount TABLE (
	Sec INT IDENTITY(1,1)
	, MasterAccountCode INT
	, AdditionalAccountCode INT
	, IdentificationValue VARCHAR(16)
)
;

-- Physical card insertion variables
DECLARE
	@CardCode VARCHAR(16)
	, @CreditCardAccountCode INT
	, @ExpirationDateString VARCHAR(8)
	, @CVV INT
	, @CreditCardAccountId INT
	, @ExpirationMonth INT
	, @ExpirationYear INT
;

DECLARE @InputPhysicalCard TABLE (
	Sec INT IDENTITY(1,1)
	, CardCode VARCHAR(16)
	, CreditCardAccountCode INT
	, ExpirationDateString VARCHAR(8)
	, CVV INT
)

-- Movements insertion 
DECLARE 
	@MovementName VARCHAR(32)
	, @CodeTF VARCHAR(16)
	, @DateMovement DATE
	, @Amount MONEY
	, @Reference VARCHAR(16)
	, @NewTFCode VARCHAR(16)
	, @NewBalance MONEY = 0
	, @Action VARCHAR(16)
	, @DescriptionMovement VARCHAR(32)
	, @IdMasterAccount INT
	, @IdMovementType INT
	, @IdPhysicalCard INT
	, @IdSubAccountState INT
	--Variable for Updates
	, @CurrentBalance MONEY
	, @QPaymentsDuringMonth INT
	, @MinPaymentDueDate DATE
	, @AccountTypeId INT
	--Interest variables
	, @RateInterestCurrent FLOAT
	, @RateInterestMorator FLOAT
	, @AmountDebitInterestCurrent MONEY
	, @BalanceInterestCurrent MONEY
	--Moratorium
	, @AccruedDebitPenaultyInterest MONEY
	, @AmountPaymentMinimumPenaulty MONEY
	, @BalanceInterestPenaulty MONEY
	--Variables to insert into interest tables
	, @CurrentMovementTypeId INT
	, @PenaultyMovementTypeId INT

	--CONSTANTS
	, @ACTION_SUM VARCHAR(8) = 'Suma'
	, @ACTION_SUB VARCHAR(8) = 'Resta'

	, @CURRENT_INTEREST_BALANCE VARCHAR(32) = 'Intereses Corrientes sobre Saldo'
	, @PENAULTY_INTEREST_BALANCE VARCHAR(32) = 'Intereses Moratorios Pago no Realizado'


DECLARE @InputMovement TABLE(
	Sec INT IDENTITY(1,1)
	, [MovementName] VARCHAR(32)
	, CodeTF VARCHAR(16)
	, DateMovement DATE
	, Amount MONEY
	, [DescriptionMovement] VARCHAR(32)
	, [Reference] VARCHAR(16)
	, [NewTFCode] VARCHAR(16)
);

-- AccountState update variables
	DECLARE
		 @QATMOperations INT = 0
		, @QBrandOperations INT = 0
		, @TotalPaymentsBeforeDueDate MONEY = 0
		, @TotalPaymentsDuringMonth MONEY = 0
		, @QPaymentsDurginMonth INT = 0
		, @TotalPurchases MONEY = 0
		, @QPurchases INT = 0
		, @TotalWithdrawals MONEY = 0
		, @QWithdrawals INT = 0
		, @TotalCredits MONEY = 0
		, @QCredits INT = 0
		, @TotalDebits MONEY = 0
		, @QDebits INT = 0
-- Temp table to load operation tables from xml
DECLARE @Dates TABLE (
	Sec INT IDENTITY(1,1)
	, [OperationDate] DATE
)

-- Temp table to load input card holders
DECLARE @InputCardHolder TABLE (
		Sec INT IDENTITY(1,1)
		, [Name]	VARCHAR(64)
		, [DocumentTypeName] VARCHAR(16)
		, [IdentificationValue] VARCHAR(16)
		, [Username] VARCHAR(16)
		, [Password] VARCHAR(16)
)
;

-- Loading xml into @xmlData variable
SET @xmlData = (
	SELECT *
	FROM OPENROWSET (
		BULK 'C:\bulk\operaciones.xml'
		, SINGLE_BLOB
	)
	AS xmlData
);

-- Processing dates from xml
INSERT INTO @Dates (
	OperationDate
)
SELECT
	T.Item.value('@Fecha', 'DATE')
FROM @xmlData.nodes('root/fechaOperacion') AS T(Item)

-- Setting iteration floor and ceil
SELECT
	@ActualRecord = MIN(D.[Sec])
	, @LastRecord = MAX(D.[sec])
FROM @Dates D


WHILE (@ActualRecord <= @LastRecord)
BEGIN
	-- Obtain actual operation date
	SELECT @ActualDate = D.OperationDate
	FROM @Dates D
	WHERE D.Sec = @ActualRecord
	
	-- Begins card holder operations
	-- Clean table for new operation date
	/*
	DELETE @InputCardHolder
	
	-- Preprocess new card holders
	INSERT INTO @InputCardHolder (
		[Name]
		, [DocumentTypeName]
		, [IdentificationValue]
		, [Username]
		, [Password]
	)
	SELECT
		T.Item.value('@Nombre', 'VARCHAR(64)')
		, T.Item.value('@Tipo_Doc_Identidad', 'VARCHAR(16)')
		, T.Item.value('@Valor_Doc_Identidad', 'VARCHAR(16)')
		, T.Item.value('@NombreUsuario', 'VARCHAR(16)')
		, T.Item.value('@Password', 'VARCHAR(16)')
	FROM @xmlData.nodes(
		'(root/fechaOperacion[@Fecha=sql:variable("@ActualDate")]/TH/TH)'
		)
	AS T(Item)

	-- Set Iteration floor and ceil
	SELECT
		@ActualIndex = MIN(ICH.Sec)
		, @LastIndex = MAX(ICH.Sec)
	FROM @InputCardHolder ICH
	*//*
	-- Begins insert iteration
	WHILE (@ActualIndex <= @LastIndex)
	BEGIN
		SELECT
			@CardHolderName = ICH.[Name]
			, @DocumentTypeName = ICH.DocumentTypeName
			, @IdentificationValue = ICH.IdentificationValue
			, @Username = ICH.Username
			, @Password = ICH.[Password]
		FROM @InputCardHolder ICH
		WHERE ICH.Sec = @ActualIndex

		-- Insert user
		INSERT INTO dbo.[User] (
			[IdUserType]
			, [Username]
			, [Password]
		)
		VALUES (
			@CardHolderUserType
			, @Username
			, @Password
		)

		-- Catch User id
		SET @ActualCardHolderId = SCOPE_IDENTITY();
		
		-- obtain document type id
		SELECT @DocumentTypeId = DT.Id
		FROM dbo.DocumentType DT
		WHERE DT.Name = @DocumentTypeName

		-- Insert into card holder table
		INSERT INTO dbo.CardHolder (
			[Id]
			, [IdDocumentType]
			, [Name]
			, [Value]
		)
		VALUES (
			@ActualCardHolderId
			, @DocumentTypeId
			, @CardHolderName
			, @IdentificationValue
		)

		
		SET @ActualIndex = @ActualIndex + 1
	END

	-- Ends car holder operations 
	*/
	/*
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
	*//*
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
			, @CreditLimit
			, @Balance
			, @AccruedCurrentInterest
			, @AccruedPenaultyInterest
		)

		INSERT INTO dbo.AccountState(
			IdMasterAccount
			, BillingPeriod
			, MinPaymentDueDate
		)
		VALUES(
			@ActualAccountId
			, @ActualDate
			, DATEADD(MONTH, 1, @ActualDate)
		)

		SET @ActualIndex = @ActualIndex + 1
	END*/
	-- End Master account insertion
	

	-- Preprocess input additional accounts
	/*
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
	FROM @InputCardHolder IAA
	*//*
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

		SET @ActualIndex = @ActualIndex + 1
	END
	-- ends additional account insertion
	*//*
	-- Preprocessing input physical cards
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
	*//*
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
	*/
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
		M.Item.value('@Nombre', 'VARCHAR(32)')
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

		--Get Interest movement type;;;;duda con el @action
		SELECT @CurrentMovementTypeId = CIMT.Id
		FROM dbo.CurrentInterestMovementType CIMT
		WHERE CIMT.Accion = @ACTION_SUM

		SELECT @PenaultyMovementTypeId = PMT.Id
		FROM dbo.CurrentInterestMovementType PMT
		WHERE PMT.Accion = @ACTION_SUB

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
		END
		--Process interest

		IF @MovementName = "Intereses Corrientes sobre Saldo"
		AND @Balance > 0
		BEGIN
			SET @RateInterestCurrent = FNGetRateInterest(@AccountTypeId
												, 'Tasa de interes corriente')
			SET @AmountDebitInterestCurrent = @Balance /
											@RateInterestCurrent /100/30

			SET @BalanceInterestCurrent = @BalanceInterestCurrent +
										@AmountDebitInterestCurrent

			SET @TotalDebits = @TotalDebits +
							@AmountDebitInterestCurrent
		END

		IF @MovementName = "Intereses Moratorios Pago no Realizado"
		AND @ActualDate > MinPaymentDueDate
		AND @TotalPaymentsBeforeDueDate < @PreviousMinPayment
		AND DATEPART(dw, @ActualDate) != 1
		BEGIN
			SET @RateInterestMorator = FNGetRateInterest(@AccountTypeId
												, 'intereses moratorios')
			SET @AmountPaymentMinimumPenaulty = @PreviousMinPayment - 
												@TotalPaymentsBeforeDueDate

			SET @AccruedDebitPenaultyInterest = @AmountPaymentMinimumPenaulty /
												@RateInterestMorator /100/30

			SET @BalanceInterestPenaulty = @BalanceInterestPenaulty +
										AccruedDebitPenaultyInterest

			SET @TotalDebits = @TotalDebits +
							@AccruedDebitPenaultyInterest
		END
		BEGIN TRY
		BEGIN TRANSACTION TProcessMovements
			-- Suspecious movement insertion
			IF dbo.FNIsExpired(@ExpirationYear, @ExpirationMonth, @ActualDate) = 1
			BEGIN
				INSERT INTO dbo.SuspiciousMovement(
					IdMasterAccount
					, IdPhysicalCard
					, [Date]
					, Amount
					, [Description]
					, [Reference]
				)
				VALUES(
					@MasterAccountId
					, @IdPhysicalCard
					, @DateMovement
					, @Amount
					, @DescriptionMovement
					, @Reference
				)
			END
			ELSE
			BEGIN
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
			END


			--INSERT interest movements
			IF @MovementName = @CURRENT_INTEREST_BALANCE
			BEGIN
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
				, @AccruedDebitPenaultyInterest
				, @RateInterestCurrent
			)
			END
			IF @MovementName = @PENAULTY_INTEREST_BALANCE
			BEGIN
			INSERT INTO dbo.InterestMoratorMovement(
				IdMasterAccount
				, IdInterestMoratorMovementType
				, [Date]
				, Amount
				, NewAccruedInterestMorator
			)
			VALUES(
				@MasterAccountId
				, @CurrentMovementTypeId
				, @ActualDate
				, @AccruedDebitPenaultyInterest
				, @RateInterestMorator
			)
			END

			-- UPDATE PROCESS

			SET @Balance = dbo.FNCalculateNewBalance(@Amount, @Action, @Balance)

			UPDATE dbo.MasterAccount 
			SET Balance = @Balance
				, AccruedCurrentInterest = AccruedCurrentInterest + @RateInterestCurrent
				, AccruedPenaultyInterest = AccruedPenaultyInterest + @RateInterestMorator
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

		--Counter
		SET @ActualIndex = @ActualIndex + 1
	END

	--End Movement insertion
	--Counter Main While
	SET @ActualRecord = @ActualRecord + 1;
END