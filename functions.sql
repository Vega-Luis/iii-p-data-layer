CREATE FUNCTION FNCalulateNewBalance(
    @inAmount MONEY
    , @inAction NVARCHAR(64)
    , @inBalance MONEY
    , @outNewBalance MONEY
)
RETURNS MONEY
AS 
BEGIN
    IF (@inAction = 'Credito')
    BEGIN
        SET @outNewBalance = @inBalance + @inAmount
    END
    ELSE
    BEGIN
        SET @outNewBalance = @inBalance - @inAmount
    END
    RETURN @outNewBalance
END;