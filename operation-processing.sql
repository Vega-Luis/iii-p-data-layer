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



	SELECT @ActualDate = DATEADD(DAY, 1, @ActualDate)
END