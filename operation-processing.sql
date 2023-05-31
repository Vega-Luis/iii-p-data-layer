-- Pricipal variables
DECLARE
	@xmlData XML
	, @ActualRecord INT
	, @LastRecord INT
	, @ActualDate DATE
	, @LastDate DATE
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
	set nocount on;
-- Getting card holder user type
SELECT @CardHolderUserType = UT.Id
FROM dbo.UserType UT
WHERE UT.[Name] = 'Targeta Habiente'

-- Master account insertion variables
DECLARE 
	@Code INT
	, @CreditLimit MONEY
	, @Balance MONEY = 0
	, @IsMaster BIT = 1
	, @CTMType VARCHAR(16)
	, @Value VARCHAR(16)
	, @IdCreditCardAccount INT
	, @IdCardHolder INT
	, @IdAccountType INT
	, @IdAccountState INT

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
	, @AccountStateId INT
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
	@MovementName VARCHAR(64)
	, @CodeTF VARCHAR(16)
	, @DateMovement DATE
	, @Amount MONEY
	, @Reference VARCHAR(16)
	--New TF
	, @NewTFCode VARCHAR(16)
	, @NewYear INT
	, @NewMonth INT
	, @NewCVV INT
	, @MonetaryAmountPC MONEY
	, @InvalidationMotiveId INT

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
	, @PreviousMinPayment MONEY
	, @AccountTypeId INT

	--CONSTANTS
	, @ACTION_SUM VARCHAR(8) = 'Suma'
	, @ACTION_SUB VARCHAR(8) = 'Resta'

	, @CURRENT_INTEREST_BALANCE VARCHAR(32) = 'Intereses Corrientes sobre Saldo'
	, @PENAULTY_INTEREST_BALANCE VARCHAR(32) = 'Intereses Moratorios Pago no Realizado'

	, @RENEWAL_FEE_CTM_RULE VARCHAR(32) = 'Cargo renovacion de TF de CTM'
	, @RENEWAL_FEE_CTA_RULE VARCHAR(32) = 'Cargo renovacion de TF de CTA'
	, @REPLACEMENT_FEE_CTM_RULE VARCHAR(32) = 'Reposicion de tarjeta de CTM'
	, @REPLACEMENT_FEE_CTA_RULE VARCHAR(32) = 'Reposicion de tarjeta de CTA'

	, @MOVEMENT_TYPE_RECOVERY_LOST VARCHAR(32) = 'Recuperacion por Perdida'
	, @MOVEMENT_TYPE_RECOVERY_THEFT VARCHAR(32) = 'Recuperacion por Robo'
	, @MOVEMENT_TYPE_RENEWAL_TF VARCHAR(32) = 'Renovacion de TF'

	, @Q_DAYS_TO_PAYMENT_RULE VARCHAR(64) = 'Cantidad de dias para pago saldo de contado'

	, @RATE_INTEREST_CURRENT VARCHAR(32) = 'Tasa de interes corriente'
	, @RATE_INTEREST_MORATOR VARCHAR(16) = 'intereses moratorios'

DECLARE @InputMovement TABLE(
	Sec INT IDENTITY(1,1)
	, [MovementName] VARCHAR(64)
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

-- Expired physical card processing
DECLARE
	 @ExpiredPhysicalCardId INT
	 , @RenewalFee MONEY
	 , @IdBusinessRuleXAccountType INT
	 , @IdBusinessRule INT
	 ;

-- Hold expired cards
DECLARE @ExpiredPhysicalCard TABLE (
	Sec INT IDENTITY(1,1)
	, Id INT
	, IdCreditCardAccount INT
)


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


--Interest variables
DECLARE @RateInterestCurrent FLOAT 
	, @RateInterestMorator FLOAT 
	, @AmountDebitInterestCurrent MONEY = 0
	, @BalanceInterestCurrent MONEY = 0
	--Moratorium
	, @AccruedDebitPenaultyInterest MONEY = 0
	, @AmountPaymentMinimumPenaulty MONEY = 0
	, @BalanceInterestPenaulty MONEY = 0
	--Variables to insert into interest tables
	, @CurrentMovementTypeId INT
	, @PenaultyMovementTypeId INT

-- Temp table Current interest


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
	@ActualDate = MIN(D.OperationDate)
	, @LastDate = MAX(D.OperationDate)
FROM @Dates D



WHILE (@ActualDate <= @LastDate)
BEGIN
	SET NOCOUNT ON;
	
	IF	EXISTS (
			SELECT 1
			FROM @Dates D
			WHERE D.OperationDate = @ActualDate)
	BEGIN
		
		-- Clear table for new operation date
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

                    
		WHILE (@ActualIndex <= @LastIndex)
		BEGIN
			SELECT 
				@Code = IMA.Code
				, @CTMType = IMA.CTMType
				, @CreditLimit = IMA.CreditLimit
				, @Value = IMA.[Value]
			FROM @InputMasterAccount IMA
			WHERE IMA.Sec = @ActualIndex

			-- Get Master Account Type
			SELECT @IdAccountType = MAT.Id
			FROM dbo.AccountType MAT
			WHERE MAT.[Name] = @CTMType

			SELECT @MinPaymentDueDate = DATEADD(DAY, dbo.FNGetQDays(@IdAccountType,
				@Q_DAYS_TO_PAYMENT_RULE)
				, @ActualDate)
	
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
			)
			VALUES(
				@ActualAccountId
				, @IdCardHolder
				, @IdAccountType
				, @CreditLimit
			)
			 
			 
			INSERT INTO dbo.AccountState(
				IdMasterAccount
				, BillingPeriod
				, MinPaymentDueDate
			)
			VALUES(
				@ActualAccountId
				, DATEADD(DAY, 30, @ActualDate)
				, @MinPaymentDueDate
			)

			SET @ActualIndex = @ActualIndex + 1
		END
		-- End Master account insertion

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

		-- Insertin physical cards *******************************************
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

	-- Ends physical cards insertion ************************************************************
	
	
		-- Movement Insertion **********************************************************************************
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
			SELECT @Action = MT.[Action]
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
			IF @MovementName = 'Pago en L�nea'
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
					UPDATE PC WITH (ROWLOCK)
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
				INSERT INTO dbo.Movement WITH (ROWLOCK)(
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
				
				DECLARE @LastId INT = SCOPE_IDENTITY();
				
				-- UPDATE PROCESS
				SET @Balance = dbo.FNCalculateNewBalance(@Amount, @Action, @Balance)

				UPDATE dbo.MasterAccount WITH (ROWLOCK)
				SET Balance = @Balance
				WHERE IdCreditCardAccount = @MasterAccountId

				UPDATE dbo.Movement WITH (ROWLOCK)
				SET NewBalance = @Balance
				WHERE @LastId = Id


				-- Always execute
				UPDATE dbo.AccountState WITH (ROWLOCK)
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
				UPDATE dbo.SubAccountState WITH (ROWLOCK)
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
		-- End Movement insertion  ********************************************************************
	

	END --End for only operation dates


	-- Begin processing interest ********************************************************************
	
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
	SELECT TOP 1  
		@MinPaymentDueDate = AST.MinPaymentDueDate
		, @PreviousMinPayment = AST.PreviousMinPayment
		, @TotalPaymentsBeforeDueDate =TotalPaymentsBeforeDueDate
	FROM dbo.AccountState AST
	WHERE AST.IdMasterAccount = @ActualIndex --
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
			UPDATE dbo.MasterAccount WITH (ROWLOCK)
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
	
		-- Procesing account states **************************************************************************************
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
        --, @Q_DAYS_TO_PAYMENT_RULE VARCHAR(64) = 'Cantidad de dias para pago saldo de contado'

		--, @IdAccountState INT
		--, @IdMasterAccount INT
		, @CreditCardCreationDate DATE
		, @StatementBalance MONEY -- Account statement balance
		--, @PreviousMinPayment MONEY
		, @BillingPeriod DATE
		--, @MinPaymentDueDate DATE
		, @LatePaymentInterest FLOAT
		--, @QATMOperations INT
		--, @QBrandOperations INT
		--, @TotalPaymentsBeforeDueDate MONEY
		, @MasterAccountFee MONEY
		, @AdditionalAccountFee MONEY
		, @FraudInsuranceFee MONEY
		, @ATMOverOperationsFEE MONEY
		, @BrandOverOperationsFee MONEY
		--, @IdMovementType INT
		, @QAdditionalAccounts INT
		, @ATMOperationsLimit INT
		, @BrandOperationsLimit INT
		--, @IdPhysicalCard INT
		--, @CurrentBalance MONEY -- Account current balance
		, @AccruedCurrentInterest MONEY
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
	AND dbo.FNIsClosingDate(CS.BillingPeriod, @ActualDate) = 1

	-- Obtaining loop index
	SELECT
		 @ActualIndex = MIN(CS.Sec)
		 , @LastIndex = MAX(CS.Sec)
	FROM @ClosingDateAccountState CS
    SET @REFERENCE  = 'Closing Account Statement'
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
			WHERE CS.Sec = @ActualIndex

			-- New billing period date
			SELECT @BillingPeriod = DATEADD(DAY, 30, @ActualDate)

			-- Select the last Physical card
			SELECT TOP 1
				@IdPhysicalCard = PC.Id
			FROM dbo.PhysicalCard PC
			WHERE PC.IdCreditCardAccount = @IdMasterAccount
			ORDER BY PC.CreationDate DESC

			-- Get master account attributes
			SELECT
				@CurrentBalance = MA.Balance
				, @AccruedCurrentInterest = MA.AccruedCurrentInterest
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

			INSERT INTO dbo.Movement with (rowlock)(
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

			INSERT INTO dbo.Movement with (rowlock)(
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

			INSERT INTO dbo.Movement with (rowlock)(
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

			UPDATE MA WITH (ROWLOCK)
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
	--Counter Main While
	SET @ActualDate = DATEADD(DAY, 1, @ActualDate)

END