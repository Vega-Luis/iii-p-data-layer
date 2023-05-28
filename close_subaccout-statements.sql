-- Trigger to close addtional account states
CREATE TRIGGER CloseSubAccountStates
ON dbo.AccountState
AFTER INSERT
AS
BEGIN
	DECLARE
		@IdAccountState INT
		, @IdMasterAccount INT
		;

	SELECT
		@IdMasterAccount = IdMasterAccount
		, @IdAccountState = Id
	FROM inserted;

	INSERT INTO dbo.SubAccountState (
		IdAdditionalAccount
		, IdAccountState
	)
	SELECT
		AA.IdCreditCardAccount
		, @IdAccountState
	FROM dbo.AdditionalAccount AA
	WHERE AA.IdMasterAccount = @IdMasterAccount;
END;

