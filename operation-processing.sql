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
--Temp table to load Movement 
DECLARE @InputMovement TABLE(
		[Name] VARCHAR(32)
		, Code INT
		, DateMovement DATE
		, Amount MONEY
		, [DescriptionMovement] NVARCHAR(32)
		, [Reference] NVARCHAR(16)
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
	DELETE @InputMovement
	
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
	--Isertion in temp table
	INSERT INTO @InputCTMaster(
		Code
		, [CTMasterType]
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
	--Movements temp
	INSERT INTO @InputMovement(
		[Name]
		, Code
		, DateMovement
		, Amount
		, [DescriptionMovement]
		, [Reference]
	)
	SELECT
		M.Item.value('@Nombre', 'VARCHAR(32)')
		, M.Item.value('@TF', 'INT')
		, M.Item.value('@FechaMovimiento', 'DATE')
		, M.Item.value('@Monto', 'MONEY')
		, M.Item.value('@Descripcion', 'NVARCHAR(32)')
		, M.Item.value('@Referencia', 'NVARCHAR(16)')
	FROM @xmlData.nodes(
		'(root/fechaOperacion[@Fecha=sql:variable("@ActualDate")]/Movimiento/Movimiento)'
	)
	AS M(Item)

	SET @ActualRecord = @ActualRecord + 1;

	-- Insertion in Database CTM
	INSERT dbo.MasterAccount(
		IdCreditCardAccount
		, IdCardHolder
		, IdAccountType
		, CreditLimit
	)
	SELECT 
		CT.Id
		, CH.Id
		, TY.Id
		, CTM.CreditLimit
	FROM dbo.CreditCardAccount CT
	INNER JOIN 
	@InputCTMaster CTM
		ON CT.Code = CTM.Code
	INNER JOIN
	dbo.CardHolder CH
		ON CH.[Value] = CTM.[Value]
	INNER JOIN
	dbo.AccountType TY
		ON CTM.CTMasterType = TY.[Name]

	--Insertion in Movement
	INSERT dbo.Movement(
		IdMasterAccount
		, IdMovementType
		, IdPhysicalCard
		, [Date]
		, Amount
		, [Description]
		, [Reference]
		, NewBalance
	)
	SELECT 
		CA.Id
		, MT.Id
		, PC.Id
		, M.DateMovement
		, M.Amount
		, M.Description
		, M.Reference
		, dbo.FNCalulateNewBalance(M.Amount, MT.Action, MA.Balance)
	FROM dbo.CreditCardAccount CA
	INNER JOIN
	dbo.PhysicalCard PC
		ON PC.Code = M.Code AND CA.IsMaster = 1
	INNER JOIN
	dbo.MovementType MT
		ON M.[Name] = MT.[Name]
	CROSS JOIN
	@InputMovement M
	INNER JOIN 
	dbo.MasterAccount MA
		ON MA.IdCreditCardAccount = CA.Id

	--Suspecious movement
	INSERT dbo.SuspiciousMovement(
		IdMasterAccount
		, IdPhysicalCard
		, [Date]
		, Amount
		, [Description]
		, [Reference]
	)
	SELECT 
		CA.Id
		, PC.Id
		, M.DateMovement
		, M.Amount
		, M.Description
		, M.Reference
	FROM dbo.CreditCardAccount CA
	INNER JOIN
	dbo.PhysicalCard PC
		ON PC.Code = M.Code AND CA.IsMaster = 1
	CROSS JOIN
	@InputMovement M
	WHERE M.DateMovement < @ActualDate

	UPDATE dbo.MasterAccount (ROWLOCK)
		SET Balance = M.NewBalance

END