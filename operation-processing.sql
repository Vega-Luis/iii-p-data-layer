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
	@MasterAccountCode INT
	, @CreditLimit MONEY
	, @Balance MONEY
	, @IsMaster BIT = 1
	, @CTMType VARCHAR(16)
	, @IdCreditCardAccount INT
	, @IdCardHolder INT
	, @IdAccountType INT
	, @AccruedCurrentInterest MONEY = 0
	, @AccruedPenaultyInterest MONEY = 0

Declare @InputMasterAccount TABLE(
	Sec INT IDENTITY(1,1)
	, MasterAccountCode INT
	, CTMType VARCHAR(16)
	, [CreditLimit] MONEY
	, [IdentificationValue] VARCHAR(16)
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
	, @ExpirationDate DATE
	, @CVV INT
	, @CreditCardAccountId INT
;

DECLARE @InputPhysicalCard TABLE (
	Sec INT IDENTITY(1,1)
	, CardCode VARCHAR(16)
	, CreditCardAccountCode INT
	, ExpirationDate DATE
	, CVV INT
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
			, [IdentificationValue]
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
		MasterAccountCode
		, [CTMType]
		, [CreditLimit]
		, [IdentificationValue]
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
			@MasterAccountCode = IMA.MasterAccountCode
			, @CTMType = IMA.CTMType
			, @CreditLimit = IMA.CreditLimit
			, @Balance = IMA.CreditLimit
			, @IdentificationValue = IMA.IdentificationValue
		FROM @InputMasterAccount IMA
		WHERE IMA.Sec = @ActualIndex

		-- Get Id of credit card account
		SELECT @IdCreditCardAccount = CCA.Id
		FROM dbo.CreditCardAccount CCA
		WHERE CCA.Code = @MasterAccountCode

		-- Get Master Account Type
		SELECT @IdAccountType = MAT.Id
		FROM dbo.AccountType MAT
		WHERE MAT.Name = CTMType

		-- Get card holder Id
		SELECT @IdCardHolder = CH.Id
		FROM dbo.CardHolder CH
		WHERE CH.Value = @IdentificationValue

		--Insertion in Credit card account
		INSERT INTO dbo.CreditCardAccount (
			Code
			, IsMaster
			, CreationDate
		)
		VALUES (
			@MasterAccountCode
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
			@IdCreditCardAccount
			, @IdCardHolder
			, @IdAccountType
			, @CreditLimit
			, @Balance
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

	-- Preprocessing input physical cards
	INSERT INTO @InputPhysicalCard (
		CardCode
		, CreditCardAccountCode
		, ExpirationDate
		, CVV
	)
	SELECT
		T.Item.value('@Codigo', 'VARCHAR(16)')
		, T.Item.value('@TCAsociada', 'INT')
		, T.Item.value('@FechaVencimiento', 'DATE')
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
			, @ExpirationDate = IPC.ExpirationDate
			, @CVV = IPC.CVV
		FROM @InputPhysicalCard IPC
		WHERE IPC.Sec = @ActualIndex

		-- Getting credit card account id
		SELECT @CreditCardAccountId = CCA.Id
		FROM dbo.CreditCardAccount CCA
		WHERE CCA.Code = @CreditCardAccountCode

		INSERT INTO dbo.PhysicalCard (
			IdCreditCardAccount
			, Code
			, ExpirationYear
			, ExpirationMonth
			, CVV
		)
		VALUES (
			@CreditCardAccountId
			, @CardCode
			, DATEPART(YEAR, @ExpirationDate)
			, DATEPART(MONTH, @ExpirationDate)
			, @CVV
		)
	END

	SET @ActualRecord = @ActualRecord + 1;
END