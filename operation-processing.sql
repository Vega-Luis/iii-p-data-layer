-- Pricipal variables
DECLARE
	@xmlData XML
	, @ActualRecord INT
	, @LastRecord INT
	, @ActualDate DATE
	;

-- Temp table to load operation tables from xml
DECLARE @Dates TABLE (
	Sec INT IDENTITY(1,1)
	, [OperationDate] DATE
)

-- Temp table to load input card holders
DECLARE @InputCardHolder TABLE (
		Sec INT IDENTITY(1,1)
		, [Name]	VARCHAR(64)
		, [DocumentType] VARCHAR(16)
		, [IdentificationValue] VARCHAR(16)
		, [UserName] VARCHAR(16)
		, [Password] VARCHAR(16)
	);
-- Temp table to load NCTMaster
DECLARE @InputCTMaster TABLE(
		Code INT
		, [CTMasterType] VARCHAR(16)
		, [CreditLimit] MONEY
		, [Value] VARCHAR(16)
);

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
	
	-- Clean table for new operation date
	DELETE @InputCardHolder
	DELETE @InputCTMaster
	
	INSERT INTO @InputCardHolder (
		[Name]
		, [DocumentType]
		, [IdentificationValue]
		, [UserName]
		, [Password]
	)
	SELECT
		T.Item.value('@Nombre', 'VARCHAR(64)')
		, T.Item.value('@Tipo_Doc_Identidad', 'VARCHAR(16)')
		, T.Item.value('@Valor_Doc_Identidad', 'VARCHAR(16)')
		, T.Item.value('@NombreUsusario', 'VARCHAR(16)')
		, T.Item.value('@Password', 'VARCHAR(16)')
	FROM @xmlData.nodes(
		'(root/fechaOperacion[@Fecha=sql:variable("@ActualDate")]/TH/TH)'
		)
	AS T(Item)

	INSERT INTO @InputCTMaster(
		Code
		, [AccountType]
		, [CreditLimit]
		, [Value]
	)
	SELECT
		CTM.Item.VALUE('@Codigo', 'INT')
		, CTM.Item.VALUE('@TipoCTM', 'VARCHAR(16)')
		, CTM.Item.VALUE('@LimiteCredito', 'MONEY')
		, CTM.Item.VALUE('@TH', 'VARCHAR(16)')
	FROM @xmlData.NODES(
		'(root/fechaOperacion[@Fecha=sql:variable("@ActualDate")]/NTCM/NTCM)'
	)
	AS CTM(Item)

	SET @ActualRecord = @ActualRecord + 1;

	-- Insertion in Database
	INSERT dbo.MasterAccount(
		IdCreditCardAccount
		, IdCardHolder
		, IdAccountType
		, CreditLimit
	)
	SELECT 
		MA.Id
		, CH.Id
		, TY.Id
		, CTM.CreditLimit
	FROM dbo.MasterAccount MA
	INNER JOIN 
	@InputCTMaster CTM
		ON MA.Code = CTM.Code
	INNER JOIN
	dbo.CardHolder CH
		ON CH.Value = CTM.Value
	INNER JOIN
	dbo.AccountType TY
		ON CTM.AccountType = TY.Name

END