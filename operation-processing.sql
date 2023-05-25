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
	/*-- Obtain actual operation date
	SELECT @ActualDate = D.OperationDate
	FROM @Dates D
	WHERE D.Sec = @ActualRecord
	*/
	
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
	*//*
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
		SET @ActualIndex = @ActualIndex + 1
	END
	-- End Master account insertion

	-- Preprocess input additional accounts
	
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

	-- Processing Account states
	-- Account States that are in closing date
	DECLARE @ClosingDateAccountState TABLE (
		Sec INT IDENTITY(1,1)
		, IdAccountState INT
		, IdMasterAccount INT
		, CurrentBalance MONEY
		, PreviousMinPayment MONEY
		, BillingPeriod DATE
		, MinPaymentDueDate DATE
		, AccruedCurrentInterest FLOAT
		, LatePaymentInterest FLOAT
		, QATMOperations INT
		, QBrandOperations INT
		, TotalPaymentsBeforeDueDate MONEY
	)

	DECLARE
		@IdAccountState INT
		, @IdMasterAccount INT
		, @CurrentBalance MONEY
		, @PreviousMinPayment MONEY
		, @BillingPeriod DATE
		, @MinPaymentDueDate DATE
		, @LatePaymentInterest FLOAT
		, @QATMOperations INT
		, @QBrandOperations INT
		, @TotalPaymentsBeforeDueDate MONEY
		;



	-- Insert into temp table on date closing account states
	INSERT @ClosingDateAccountState
	SELECT
   		CS.Id
		, CS.IdMasterAccount
   		, CS.CurrentBalance
   		, CS.PreviousMinPayment
   		, CS.BillingPeriod
   		, CS.MinPaymentDueDate
   		, CS.AccruedCurrentInterest
   		, CS.LatePaymentInterest
   		, CS.QATMOperations
   		, CS.QBrandOperations
   		, CS.TotalPaymentsBeforeDueDate
	FROM dbo.AccountState CS
    INNER JOIN dbo.CreditCardAccount CCA
	ON CCA.Id = CS.IdMasterAccount
	AND DATEPART(DAY, CCA.CreationDate) = DATEPART(DAY, @ActualDate)
	
	-- Obtaining loop index
	SELECT
		 @ActualIndex = MIN(CS.Sec)
		 , @LastIndex = MAX(CS.Sec)
	FROM @ClosingDateAccountState CS
	
	DECLARE @UpdatedAccountState TABLE (
		Sec INT IDENTITY(1,1)
		, IdAccountState INT
		, CurrentBalance MONEY
		, PreviousMinPayment MONEY
		, AccruedCurrentInterest FLOAT
		, LatePaymentInterest FLOAT
		, BillingPeriod DATE
		, MinPaymentDueDate DATE
	)

	DECLARE @ClosingAccountStateMovement TABLE (
		Sec INT IDENTITY(1,1)
		, IdMasterAccount INT
		, IdMovementType INT
		, IdAccountState INT
		, IdPhysicalCard INT
		, [Description] VARCHAR(64)
		, [Date] DATE
		, Amount MONEY
		, Reference VARCHAR(64)
		, NewBalance MONEY
	)

	-- Go through every record
	WHILE (@ActualIndex <= @LastIndex)
	BEGIN
		-- GET AccountState records on actual index
		SELECT
			@IdAccountState = CS.IdAccountState
			, @IdMasterAccount = CS.IdMasterAccount
			, @CurrentBalance = CS.CurrentBalance
			, @PreviousMinPayment = CS.PreviousMinPayment
			, @BillingPeriod = CS.BillingPeriod
			, @MinPaymentDueDate = CS.MinPaymentDueDate
			, @LatePaymentInterest = CS.LatePaymentInterest
			, @AccruedCurrentInterest = CS.AccruedCurrentInterest
			, @QATMOperations = CS.QATMOperations
			, @QBrandOperations = CS.QBrandOperations
			, @TotalPaymentsBeforeDueDate = CS.TotalPaymentsBeforeDueDate
		FROM @ClosingDateAccountState CS

		DECLARE
			@MasterAccountFee MONEY
			, @AdditionalAccountFee MONEY
			, @FraudInsuranceFee MONEY
			, @ATMOverOperationsFEE MONEY
			, @BrandOverOperationsFee MONEY
			, @IdMovementType INT
			, @MOVEMENT_TYPE_SERVICES  VARCHAR(64) = 'Cargos por Servicio'
			, @MASTER_ACCOUNT_SERVICES_RULE VARCHAR(64) = 'Cargos Servicio Mensual CTM'
			, @ADDITIONAL_ACCOUNT_SERVICES_RULE VARCHAR(64) = 'Cargos Servicio Mensual CTA'
			, @FRAUD_INSURANCE_RULE VARCHAR(64) = 'Cargo Seguro Contra Fraudes'
			, @OVER_ATM_OPERATIONS_RULE VARCHAR(64) = 'Multa exceso de operaciones ATM'
			, @OVER_BRAND_OPERATIONS_RULE VARCHAR(64) = 'Multa exceso de operaciones Ventanilla'
			, @ATM_OPERATIONS_LIMIT_RULE VARCHAR(64) = 'Cantidad de opraciones en ATM'
			, @BRAND_OPERATIONS_LIMIT_RULE VARCHAR(64) = 'Cantidad de operacion en Ventanilla'
			, @REFERENCE VARCHAR(64) = 'Closing Account State'
			, @QAdditionalAccounts INT
			, @ATMOperationsLimit INT
			, @BrandOperationsLimit INT
			, @IdPhysicalCard INT
			;

			SELECT TOP 1
				@IdPhysicalCard = PC.Id
			FROM dbo.PhysicalCard PC
			WHERE PC.IdCreditCardAccount = @IdMasterAccount
			ORDER BY PC.CreationDate DESC


			-- Get total additional accounts
			SELECT @QAdditionalAccountS = COUNT(AA.IdCreditCardAccount)
			FROM dbo.AdditionalAccount AA
			WHERE AA.IdMasterAccount = @MasterAccountId

			-- Get account type id
			SELECT @IdAccountType = T.Id
			FROM dbo.AccountType T
			INNER JOIN dbo.MasterAccount M
				ON M.IdAccountType = T.Id

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

			-- Inserting master account service fee movement

			-- Gettting movement type id
			SET @IdMovementType = dbo.FNGetMovementTypeId(@MOVEMENT_TYPE_SERVICES)

			SET @CurrentBalance = @CurrentBalance - @MasterAccountFee
			INSERT @ClosingAccountStateMovement 
			VALUES (
				@IdMasterAccount
				, @IdMovementType
				, @IdAccountState
				, @IdPhysicalCard
				, @MASTER_ACCOUNT_SERVICES_RULE
				, @ActualDate
				, @MasterAccountFee
				, @REFERENCE
				, @CurrentBalance
			)

			-- Inserting additional account servise fee movement
			SET @CurrentBalance = @CurrentBalance - @AdditionalAccountFee
			INSERT @ClosingAccountStateMovement
			VALUES (
				@IdMasterAccount
				, @IdMovementType
				, @IdAccountState
				, @IdPhysicalCard
				, @ADDITIONAL_ACCOUNT_SERVICES_RULE
				, @ActualDate
				, @AdditionalAccountFee
				, @REFERENCE
				, @CurrentBalance
			)

			-- Inserting fraud insurance servise fee movement
			SET @CurrentBalance = @CurrentBalance - @FraudInsuranceFee
			INSERT @ClosingAccountStateMovement
			VALUES (
				@IdMasterAccount
				, @IdMovementType
				, @IdAccountState
				, @IdPhysicalCard
				, @FRAUD_INSURANCE_RULE
				, @ActualDate
				, @FraudInsuranceFee
				, @REFERENCE
				, @CurrentBalance
			)

			IF @QATMOperations > dbo.FNGetOperationsAmount(@IdAccountType,
							@ATM_OPERATIONS_LIMIT_RULE)
			BEGIN
				-- Inserting over atm operations  charge movement
				SET @CurrentBalance = @CurrentBalance - @ATMOverOperationsFEE
				INSERT @ClosingAccountStateMovement
				VALUES (
					@IdMasterAccount
					, @IdMovementType
					, @IdAccountState
					, @IdPhysicalCard
					, @OVER_ATM_OPERATIONS_RULE
					, @ActualDate
					, @ATMOverOperationsFEE
					, @REFERENCE
					, @CurrentBalance
				)
			END

			IF @QBrandOperations > dbo.FNGetOperationsAmount(@IdAccountType,
							@BRAND_OPERATIONS_LIMIT_RULE)
				BEGIN
							-- Inserting fraud insurance servise fee movement
				SET @CurrentBalance = @CurrentBalance - @BrandOverOperationsFee
				INSERT @ClosingAccountStateMovement
				VALUES (
					@IdMasterAccount
					, @IdMovementType
					, @IdAccountState
					, @IdPhysicalCard
					, @OVER_BRAND_OPERATIONS_RULE
					, @ActualDate
					, @BrandOverOperationsFee
					, @REFERENCE
					, @CurrentBalance
				)
			END

			INSERT @UpdatedAccountState
			VALUES (
				@IdAccountState 
				, @CurrentBalance 
				, @PreviousMinPayment 
				, @AccruedCurrentInterest 
				, @LatePaymentInterest 
				, @BillingPeriod 
				, @MinPaymentDueDate 
			)
		SET @ActualIndex = @ActualIndex + 1
	END
	




	-- Updating Master Account states 
	UPDATE A
	SET
		A.CurrentBalance = T.CurrentBalance
		, A.PreviousMinPayment = T.PreviousMinPayment
		, A.BillingPeriod = T.BillingPeriod
		, A.MinPaymentDueDate = T.MinPaymentDueDate
		, A.AccruedCurrentInterest = T.AccruedCurrentInterest
		, A.LatePaymentInterest = T.LatePaymentInterest
		, A.QATMOperations = 0              
		, A.QBrandOperations = 0
		, A.TotalPaymentsBeforeDueDate = 0
		, A.TotalPaymentsDuringMonth = 0
		, A.QPaymentsDuringMonth = 0
		, A.TotalPurchases = 0
		, A.QPurchases = 0
		, A.TotalWithdrawals = 0
		, A.QWithdrawals = 0
		, A.TotalCredits = 0
		, A.QCredits = 0
		, A.TotalDebits = 0
		, A.QDebits = 0
	FROM dbo.AccountState A
	INNER JOIN  @UpdatedAccountState T ON A.id = T.IdAccountState;
	
	-- Updating Additional Accounts States
	UPDATE SAS
	SET
		SAS.QATMOperations = 0              
		, SAS.QBrandOperations = 0
		, SAS.TotalPurchases = 0
		, SAS.QPurchases = 0
		, SAS.TotalWithdrawals = 0
		, SAS.QWithdrawals = 0
		, SAS.TotalCredits = 0
		, SAS.TotalDebits = 0
	FROM dbo.SubAccountState SAS
	INNER JOIN  @ClosingDateAccountState CS 
		ON SAS.IdAccountState = CS.IdAccountState;

	SELECT @ActualDate = DATEADD(DAY, 1, @ActualDate)
END