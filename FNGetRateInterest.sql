-- Returns the amonetary amount given the accountTypeId and BussinesRuleName
CREATE FUNCTION	dbo.FNGetRateInterest (
	@inAccountTypeId INT
	, @inBusinessRuleName VARCHAR(64)
)
RETURNS FLOAT
AS
BEGIN
	DECLARE
		@outRate FLOAT
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

	SELECT @outRate = R.Rate 
	FROM dbo.AccountTypeXBusinessRuleMonetaryAmount R
	WHERE R.IdAccountTypeXBusinessRule = @AccountTypeXBusinessRuleId

	RETURN @outRate
END