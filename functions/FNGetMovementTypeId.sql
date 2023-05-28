CREATE FUNCTION dbo.FNGetMovementTypeId (
    @inMovementTypeName VARCHAR(64)
)
RETURNS INT
AS
BEGIN
    DECLARE @outIdMovementType int

    SELECT @outIdMovementType = MT.Id
    FROM dbo.MovementType MT
    WHERE MT.[Name] = @inMovementTypeName

    RETURN @outIdMovementType
END