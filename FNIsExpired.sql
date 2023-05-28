CREATE FUNCTION dbo.FNIsExpired(
    @inExpirationYear INT
    , @inExpirationMonth INT
    , @inOperationDate DATE
)
RETURNS BIT
AS
BEGIN
	DECLARE @outIsExpired BIT;

    IF DATEPART(YEAR, @inOperationDate) = @inExpirationYear
	AND DATEPART(MONTH, @inOperationDate) > @inExpirationMonth
        SET @outIsExpired = 1;
    ELSE
		SET @outIsExpired =  0;
	RETURN @outIsExpired;
END;