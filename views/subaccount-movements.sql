CREATE OR ALTER VIEW dbo.AdditionalAccountMovement
AS
SELECT
	M.Id
	, SS.Id AS IdSubAccountState
	, PC.Code AS PhysicalCardCode
	, MT.[Name] AS MovementTypeName
    , S.[BillingPeriod]
	, M.[Description]
	, M.Reference
	, M.Amount
	, M.NewBalance
FROM dbo.Movement M
INNER JOIN dbo.MovementType MT
	ON	M.IdMovementType = MT.Id
INNER JOIN dbo.PhysicalCard PC
	ON PC.Id = M.IdPhysicalCard
INNER JOIN dbo.AccountState S
	ON S.Id = M.IdAccountState
INNER JOIN dbo.SubAccountState SS
	ON SS.IdAccountState = S.Id
AND SS.IdAdditionalAccount = PC.IdCreditCardAccount
