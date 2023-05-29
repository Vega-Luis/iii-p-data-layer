-- SP
-- Gets the Master account Movements from a selected account state card
CREATE PROCEDURE dbo.GetAdditionalAccountMovement
    @inIdSubAccountState INT
    , @inIdAccountState INT
	, @inPostUser VARCHAR(64)
	, @inPostIp VARCHAR(64)
	, @outResultCode INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		DECLARE @LogDescription VARCHAR(256) = 
                        '{Action Type = Get Additional Account Movements'
						+ 'Description = ' 
						+ @inIdSubAccountState + '}'

		DECLARE @postIdUser INT;
        SET @outResultCode = 0;                     -- No error code

        SELECT
            M.IdSubAccountState
            , M.[Date]
            , M.MovementTypeName
            , M.Reference
            , M.Amount
            , M.NewBalance
        FROM dbo.AdditionalAccountMovement M
        WHERE M.IdAccountState = @inIdAccountState
        AND M.IdSubAccountState = @inIdSubAccountState
			
		--Insert in EventLog table
		INSERT dbo.EventLog(
			[LogDescription]
			, [PostIdUser]
			, [PostIp]
			, [PostTime])
		VALUES (
			@LogDescription
			, @postIdUser
			, @inPostIp
			, GETDATE()
			);
    END TRY
    BEGIN CATCH
        INSERT INTO dbo.DBErrors	VALUES (
            SUSER_SNAME(),
            ERROR_NUMBER(),
            ERROR_STATE(),
            ERROR_SEVERITY(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            ERROR_MESSAGE(),
            GETDATE()
        );

        Set @outResultCode=50009;                   -- Error code
    END CATCH
	SET NOCOUNT OFF;
END;