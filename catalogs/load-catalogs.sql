DECLARE @xmlData XML

-- Admin user type
DECLARE @ADMIN_USER_TYPE VARCHAR(16) = 'Administrador';
DECLARE @IdUserType INT;

-- Getting user type Id
SELECT @IdUserType = UT.Id
FROM dbo.UserType UT
WHERE UT.[Name] = @ADMIN_USER_TYPE

SET @xmlData = (
	SELECT *
	FROM OPENROWSET (
		BULK 'C:\bulk\catalogos.xml'
		, SINGLE_BLOB
	)
	AS	xmlData
);

-- Insert document types from loaded xml data
INSERT INTO dbo.[DocumentType] (
	[Name]
	, [Format]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(64)')
	, T.Item.value('@Formato', 'VARCHAR(16)')
FROM @xmlData.nodes('root/TDI/TDI') AS T(Item)

-- Insert account types from loaded xml data
INSERT INTO dbo.[AccountType] (
	[Name]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(64)')
FROM @xmlData.nodes('root/TCTM/TCTM') AS T(Item)

-- Insert invalidation motives from loaded xml data
INSERT INTO dbo.InvalidationMotive (
	[Name]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(32)')
FROM @xmlData.nodes('root/MIT/MIT') AS T(Item)

-- Insert users from loaded xml data
INSERT INTO dbo.[User] (
	IdUserType
	, [Username]
	, [Password]
)
SELECT
	@IdUserType
	, T.Item.value('@Nombre', 'VARCHAR(32)')
	, T.Item.value('@Password', 'VARCHAR(32)')
FROM @xmlData.nodes('root/UA/Usuario') AS T(Item)

-- Insert business rule types from loaded xml data
INSERT INTO dbo.[BusinessRuleType] (
	[Name]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(64)')
FROM @xmlData.nodes('root/TRN/TRN') AS T(Item)

-- Insert business rules values from loaded xml data
-- Creating a temporary table to quickly store input data
DECLARE @TempBusinessRule TABLE (
	Id INT IDENTITY(1,1)
	, [Name] VARCHAR(64)
	, [AccountTypeName] VARCHAR(16)
	, [BusinessRuleTypeName] VARCHAR(32)
	, [BusinessRuleValue] FLOAT
)

-- Inserting data into temporary table
INSERT INTO @TempBusinessRule (
	[Name]
	, [AccountTypeName]
	, [BusinessRuleTypeName]
	, [BusinessRuleValue]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(64)')
	, T.Item.value('@TCTM', 'VARCHAR(16)')
	, T.Item.value('@TipoRN', 'VARCHAR(32)')
	, T.Item.value('@Valor', 'FLOAT')
FROM @xmlData.nodes('root/RN/RN') AS T(Item)

-- Variables to loop through the temp table
DECLARE
	@lo INT = 1 -- Firt record
	, @hi INT	-- Last record
	, @BusinessRuleName VARCHAR(64)
	, @AccountTypeName VARCHAR(16)
	, @BusinessRuleTypeName VARCHAR(32)
	, @BusinessRuleValue FLOAT
	, @BusinessRuleLastId	INT -- Save last BusinessRule table id
	, @AccountTypeXBusinessRuleLastId INT	-- Save last table id
	, @AccountTypeId INT
	, @BusinessRuleTypeId INT
	;

-- Set stop
SELECT
	@hi = MAX(TBR.Id)
FROM @TempBusinessRule TBR;

WHILE (@lo <= @hi)
BEGIN
	-- Get table record
	SELECT
		@BusinessRuleName = TBR.[Name]
		, @AccountTypeName = TBR.[AccountTypeName]
		, @BusinessRuleTypeName = TBR.[BusinessRuleTypeName]
		, @BusinessRuleValue = TBR.[BusinessRuleValue]
	FROM @TempBusinessRule TBR
	WHERE TBR.Id=@lo;

	-- Obtain BusinessRuleType id
	SELECT
		@BusinessRuleTypeId = Id
	FROM dbo.BusinessRuleType BRT
	WHERE BRT.[Name] = @BusinessRuleTypeName

	-- Inserting into bussines rule table 
	INSERT INTO dbo.BusinessRule (
		IdBusinessRuleType
		, [Name]
	)
	VALUES (
		@BusinessRuleTypeId
		, @BusinessRuleName
	)

	SET @BusinessRuleLastId = SCOPE_IDENTITY();	-- Catch last BussinesRule table id

	-- Obtain Account Type Id
	SELECT
		@AccountTypeId = A.Id
	FROM dbo.AccountType A
	WHERE A.[Name] = @AccountTypeName;

	-- Inserting into AccountTypeXBusinessRule Table
	INSERT INTO dbo.AccountTypeXBussinesRule (
		IdAccountType
		, IdBusinessRule
		)
	VALUES (
		@AccountTypeId
		, @BusinessRuleLastId
	)

	SET @AccountTypeXBusinessRuleLastId = SCOPE_IDENTITY(); -- Catch last AccountTypeXBusinessRule id

	-- Insert Business rules values
	IF (@BusinessRuleTypeName = 'Monto Monetario') -- Monetary amount
	BEGIN
		INSERT INTO dbo.AccountTypeXBusinessRuleMonetaryAmount (
			IdAccountTypeXBusinessRule
			, Amount
		)
		VALUES (
			@AccountTypeXBusinessRuleLastId
			, @BusinessRuleValue
		)
	END
	ELSE IF (@BusinessRuleTypeName = 'Porcentaje')
	BEGIN
		INSERT INTO dbo.AccountTypeXBusinessRuleRate (
			IdAccountTypeXBusinessRule
			, Rate
		)
		VALUES (
			@AccountTypeXBusinessRuleLastId
			, @BusinessRuleValue
		)
	END
	ELSE IF (@BusinessRuleTypeName = 'Cantidad de Operaciones')
	BEGIN
		INSERT INTO dbo.AccountTypeXBusinessRuleOperation (
			IdAccountTypeXBusinessRule
			, QOperations
		)
		VALUES (
			@AccountTypeXBusinessRuleLastId
			, @BusinessRuleValue
		)
	END
	ELSE	IF (@BusinessRuleTypeName = 'Cantidad de Dias')
	BEGIN
		INSERT INTO dbo.AccountTypeXBusinessRuleDays (
			IdAccountTypeXBusinessRule
			, QDays
		)
		VALUES (
			@AccountTypeXBusinessRuleLastId
			, @BusinessRuleValue
		)
	END

	SET @lo = @lo + 1;
END

-- Insert movement types from loaded xml data
-- Creating a temporary movement types table
DECLARE @TempMovementType TABLE (
	[Name] VARCHAR(64)
	, [Action] VARCHAR(64)
	, AccumulateATMOperation VARCHAR(2)
	, AccumulateWindowOperation VARCHAR(2)
)
-- Inserting xml data into temporary table
INSERT INTO @TempMovementType (
	[Name]
	, [Action]
	, [AccumulateATMOperation]
	, [AccumulateWindowOperation]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(64)')
	, T.Item.value('@Accion', 'VARCHAR(64)')
	, T.Item.value('@Acumula_Operacion_ATM', 'VARCHAR(2)')
	, T.Item.value('@Acumula_Operacion_Ventana', 'VARCHAR(2)')
FROM @xmlData.nodes('root/TM/TM') AS T(Item)

-- Inserting data into movement type table
INSERT INTO dbo.MovementType (
	[Name]
	, [Action]
	, [AccumulateATMOperation]
	, [AccumulateWindowOperation]
)
SELECT
	[Name]
	, [Action]
	, IIF(AccumulateATMOperation = 'SI', 1, 0)
	, IIF(AccumulateWindowOperation = 'SI', 1, 0)
FROM @TempMovementType

-- Inserting data into interest movement type tables
DECLARE @InputInterestMovementType TABLE (
	[Name] VARCHAR(64)
	, [Action] VARCHAR(8)
)
INSERT INTO @InputInterestMovementType (
	[Name]
	, [Action]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(64)')
	, T.Item.value('@Accion', 'VARCHAR(8)')
FROM @xmlData.nodes('root/TMTI/TMTI') AS T(Item)

-- Inserting interest movement types into db
INSERT INTO dbo.InterestMoratorMovementType (
	[Name]
	, [Action]
)
SELECT
	IMT.[Name]
	, IMT.[Action]
FROM @InputInterestMovementType IMT

-- Inserting interest movement types into db
INSERT INTO dbo.CurrentInterestMovementType(
	[Name]
	, [Action]
)
SELECT
	IMT.[Name]
	, IMT.[Action]
FROM @InputInterestMovementType IMT


-- Load new Physical cards for renovation
INSERT INTO dbo.NewPhysicalCard (
	Code
)
SELECT
	T.Item.value('Numero', 'VARCHAR(16)')
FROM @xmlData.nodes('root/NuevasTF/NuevaTF') AS T(Item)