CREATE FUNCTION FNCalculateNewBalance(
    @inAmount MONEY
    , @inAction VARCHAR(16)
    , @inBalance MONEY
)
RETURNS MONEY
AS
BEGIN
    DECLARE @outResultBalance MONEY
    IF(@inAction = 'Credito')
    BEGIN
        SET @outResultBalance = @inBalance + @inAmount
    END
    ELSE
    BEGIN
        SET @outResultBalance = @inBalance - @inAmount
    END
    RETURN @outResultBalance
END;