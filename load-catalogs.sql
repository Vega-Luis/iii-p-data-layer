DECLARE @xmlData XML

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
	[Name]
	, [Password]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(32)')
	, T.Item.value('@Password', 'VARCHAR(32)')
FROM @xmlData.nodes('root/UA/Usuario') AS T(Item)

-- Insert business rule types from loaded xml data
INSERT INTO dbo.[BusinessRuleType] (
	[Name]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(64)')
FROM @xmlData.nodes('root/TRN/TRN') AS T(Item)

-- Insert business rules from loaded xml data
-- Creating a temporary table to quickly store input data
DECLARE @TempBusinessRule TABLE (
	Id INT IDENTITY(1,1)
	, [Name] VARCHAR(64)
	, [AccountTypeName] VARCHAR(16)
	, [BusinessRuleTypeName] VARCHAR(32)
	, [Value] FLOAT
)
-- Inserting data into temporary table
INSERT INTO @TempBusinessRule (
	[Name]
	, [AccountTypeName]
	, [BusinessRuleTypeName]
	, [Value]
)
SELECT
	T.Item.value('@Nombre', 'VARCHAR(64)')
	, T.Item.value('@TCTM', 'VARCHAR(16)')
	, T.Item.value('@TipoRN', 'VARCHAR(32)')
	, T.Item.value('@Valor', 'FLOAT')
FROM @xmlData.nodes('root/RN/RN') AS T(Item)

-- Inserting into Business Rule
INSERT INTO dbo.BusinessRule (
	IdBusinessRuleType
	,[Name]
)
SELECT
	BRT.Id
	, TBR.[Name]
FROM @TempBusinessRule TBR
INNER JOIN dbo.BusinessRuleType BRT
ON TBR.BusinessRuleTypeName = BRT.[Name]

INSERT INTO dbo.AccountTypeXBussinesRule (
	[IdAccountType]
	, [IdBusinessRule]
)
SELECT
	[AT].Id
	, BR.Id
FROM dbo.BusinessRule BR
INNER JOIN @TempBusinessRule TBR
ON BR.[Name] = TBR.[Name]
INNER JOIN dbo.AccountType [AT]
ON [AT].[Name] = TBR.AccountTypeName
	
-- Inserting Account Type x Business Rule Days
INSERT INTO dbo.AccountTypeXBusinessRuleDays (
	IdAccountTypeXBusinessRule
	, QDays
)
SELECT
	AXR.Id
	, TBR.[Value]
FROM dbo.AccountTypeXBussinesRule AXR
INNER JOIN dbo.BusinessRule BR
ON BR.Id = AXR.IdBusinessRule
INNER JOIN @TempBusinessRule TBR
ON TBR.[Name] = BR.[Name]

-- Inserting Account Type x Business Rule Months
INSERT INTO dbo.AccountTypeXBusinessRuleMonths(
	IdAccountTypeXBusinessRule
	, QMonths
)
SELECT
	AXR.Id
	, TBR.[Value]
FROM dbo.AccountTypeXBussinesRule AXR
INNER JOIN dbo.BusinessRule BR
ON BR.Id = AXR.IdBusinessRule
INNER JOIN @TempBusinessRule TBR
ON TBR.[Name] = BR.[Name]

-- Inserting Account Type x Business Rule Monetary
INSERT INTO dbo.AccountTypeXBusinessRuleMonetaryAmount(
	IdAccountTypeXBusinessRule
	, Amount
)
SELECT
	AXR.Id
	, TBR.[Value]
FROM dbo.AccountTypeXBussinesRule AXR
INNER JOIN dbo.BusinessRule BR
ON BR.Id = AXR.IdBusinessRule
INNER JOIN @TempBusinessRule TBR
ON TBR.[Name] = BR.[Name]

-- Inserting Account Type x Business Rule operation
INSERT INTO dbo.AccountTypeXBusinessRuleOperation (
	IdAccountTypeXBusinessRule
	, QOperations
)
SELECT
	AXR.Id
	, TBR.[Value]
FROM dbo.AccountTypeXBussinesRule AXR
INNER JOIN dbo.BusinessRule BR
ON BR.Id = AXR.IdBusinessRule
INNER JOIN @TempBusinessRule TBR
ON TBR.[Name] = BR.[Name]

-- Inserting Account Type x Business Rule Days
INSERT INTO dbo.AccountTypeXBusinessRuleRate (
	IdAccountTypeXBusinessRule
	, Rate
)
SELECT
	AXR.Id
	, TBR.[Value]
FROM dbo.AccountTypeXBussinesRule AXR
INNER JOIN dbo.BusinessRule BR
ON BR.Id = AXR.IdBusinessRule
INNER JOIN @TempBusinessRule TBR
ON TBR.[Name] = BR.[Name]

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
