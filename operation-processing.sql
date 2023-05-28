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
	, @AccruedDebitPenaultyInterest MONEY
	, @AmountPaymentMinimumPenaulty MONEY
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
		SELECT 1;
	END --End for only operation dates
	
	--Counter Main While
	SET @ActualDate = DATEADD(DAY, 1, @ActualDate)
	
=======
WHILE (@ActualDate <= @LastDate)
BEGIN



	SELECT @ActualDate = DATEADD(DAY, 1, @ActualDate)

END