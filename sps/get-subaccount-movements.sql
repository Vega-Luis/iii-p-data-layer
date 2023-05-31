
-- SP
-- Gets the Master account Movements from a selected account state card
CREATE   PROCEDURE [dbo].[GetAdditionalAccountMovement]
    @inIdSubAccountState INT
    , @inPhysicalCardCode VARCHAR(16)
	, @inUsername VARCHAR(16)
	, @inPostIp VARCHAR(64)
	, @outResultCode INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		DECLARE
			@PostUserId INT
			, @LogDescription VARCHAR(256) = 
                        '{Action Type = Get Additional Account Movements '
						+ 'Description = ' 
						+ @inPhysicalCardCode+ '}'

        SET @outResultCode = 0;                     -- No error code

        SELECT
            M.Id
            , CAST(M.BillingPeriod AS VARCHAR(16)) AS BillingPeriod
            , M.MovementTypeName
            , M.Reference
			, M.[Description]
            , M.Amount
            , M.NewBalance
        FROM dbo.AdditionalAccountMovement M
        WHERE M.PhysicalCardCode = @inPhysicalCardCode
		ORDER BY M.BillingPeriod DESC
		
		
		SELECT @PostUserId = U.Id
		FROM dbo.[User] U
		WHERE U.[Username] = @inUsername;
		--Insert in EventLog table
		INSERT dbo.EventLog(
			[LogDescription]
			, [PostIdUser]
			, [PostIp]
			, [PostTime])
		VALUES (
			@LogDescription
			, @PostUserId
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