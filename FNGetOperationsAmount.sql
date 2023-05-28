-- Returns the amonetary amount given the accountTypeId and BussinesRuleName
CREATE FUNCTION	dbo.FNGetOperationsAmount(
	@inAccountTypeId INT
	, @inBusinessRuleName VARCHAR(64)
)
RETURNS MONEY
AS
BEGIN
	DECLARE
		@outAmount  INT 
		, @AccountTypeXBusinessRuleId INT
	;

	 SELECT
		@AccountTypeXBusinessRuleId = X.Id
	 FROM dbo.AccountTypeXBussinesRule X
	 INNER JOIN dbo.BusinessRule BR
		ON BR.Id = X.Id
	 INNER JOIN dbo.AccountType T
		ON T.Id = X.IdAccountType
	WHERE BR.[Name] = @inBusinessRuleName
	AND T.Id = @inAccountTypeId

	SELECT @outAmount = O.QOperations
	FROM dbo.AccountTypeXBusinessRuleOperation O
	WHERE O.IdAccountTypeXBusinessRule = @AccountTypeXBusinessRuleId

	RETURN @outAmount
END