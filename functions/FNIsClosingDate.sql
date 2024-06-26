-- Checks if the operation date is a account state closing date
CREATE OR ALTER FUNCTION dbo.FNIsClosingDate (
    @inMasterAccountCreationDate DATE
    , @inOperationDate DATE
)
RETURNS BIT
AS
BEGIN
    DECLARE @outIsClosingDate BIT; -- Operation result 1 if it is, 0 if it is not
    
	-- Case creation date day equals operations date day
	IF DATEPART(MONTH, @inOperationDate) = DATEPART(MONTH, @inBillingPeriod)
			AND
			( DATEPART(DAY, @inBillingPeriod) = DATEPART(DAY, @inOperationDate)
				OR
				(
					-- Operation date is en of month
					-- and creation date is greater than operation date
					EOMONTH(@inOperationDate) = @inOperationDate
					AND
					DATEPART(DAY, EOMONTH(@inOperationDate)) < DATEPART(DAY, @inBillingPeriod)
				)
			)
        SET @outIsClosingDate = 1;
    ELSE
        SET @outIsClosingDate = 0;
    RETURN @outIsClosingDate;
END;