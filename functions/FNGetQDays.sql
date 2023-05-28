-- Returns the amount of days given the accountTypeId and BussinesRuleName
CREATE FUNCTION	dbo.FNGetMonetaryAmount (
	@inAccountTypeId INT
	, @inBusinessRuleName VARCHAR(64)
)
RETURNS MONEY
AS
BEGIN
	DECLARE
		@outQDays INT
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

	SELECT @outQDays = R.QDays
	FROM dbo.AccountTypeXBusinessRuleDays R
	WHERE R.IdAccountTypeXBusinessRule = @AccountTypeXBusinessRuleId

	RETURN @outQDays
END