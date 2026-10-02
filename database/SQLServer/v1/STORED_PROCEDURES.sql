CREATE OR ALTER PROCEDURE dbo.[GetUserByUsername]
    @Username nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.[Id], u.[Username], u.[PasswordHash], u.[Name]
    FROM dbo.[Users] u
    WHERE u.[Username] = @Username
      AND DATALENGTH(u.[Username]) = DATALENGTH(@Username)
      AND u.[IsActive] = 1;
END;
GO
