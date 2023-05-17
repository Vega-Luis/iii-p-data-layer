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
	, @IdentificationValue VARCHAR(16)
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

	-- Set Iteration floor
	SELECT @ActualIndex = MIN(ICH.Sec)
	FROM @InputCardHolder ICH

	-- Set iteration ceil
	SELECT @LastIndex = MAX(ICH.Sec)
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

	SET @ActualRecord = @ActualRecord + 1;
END