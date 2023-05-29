-- SP
-- Gets the Master account Movements from a selected account state card
CREATE PROCEDURE dbo.GetMasterAccountMovements
	@inIdAccountState INT
	, @inPostUser VARCHAR(64)
	, @inPostIp VARCHAR(64)
	, @outResultCode INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		DECLARE @LogDescription VARCHAR(256) = 
                        '{Action Type = Get Master Account Movements'
						+ 'Description = ' 
						+ @inIdAccountState + '}'

		DECLARE @postIdUser INT;
        SET @outResultCode = 0;                     -- No error code

        SELECT
            M.Id
            , M.[Date]
            , MT.[Name]
            , M.Description
            , M.[Reference]
            , M.Amount
            , M.NewBalance
        FROM dbo.Movement M
        INNER JOIN dbo.MovementType MT
            ON M.IdMovementType = MT.Id
        AND MT.IdAccountState = @inIdAccountState
			
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