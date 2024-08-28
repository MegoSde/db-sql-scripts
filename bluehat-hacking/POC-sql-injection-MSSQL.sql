-- Formål: Demonstrere sårbarheden for SQL injection i en MSSQL-database
-- Tip: Sørg for at afvikle kommandoerne en ad gangen for at forstå konsekvenserne.

-- -----------------------------------------------------------------------------------------------------
-- Opsætning: Lav tabeller og bruger til demonstrationen
-- Overvej at lave en test database, I kan bruge til formålet
-- -----------------------------------------------------------------------------------------------------

-- Login som dbo
-- Lav to tabeller med data som udgangspunkt
CREATE TABLE [users] (
    [Name] VARCHAR(100) PRIMARY KEY, 
    [Password] VARBINARY(100) 
);
GO

INSERT INTO [users] ([Name], [Password]) VALUES ('Mads', HASHBYTES('SHA2_512', 'password'));
GO

CREATE TABLE [secrets] (
    [Text] VARCHAR(100)
);
GO

INSERT INTO [secrets] ([Text]) VALUES ('Hemmelighed');
GO

-- Create a [webtester] user, som skal simulere at være den bruger en evt. hjemmeside eller web API bruger
CREATE USER [webtester] WITHOUT LOGIN WITH DEFAULT_SCHEMA=[dbo];
GO

-- Vis hvad der er lagt ind
SELECT * FROM [users];
SELECT * FROM [secrets];

-- -----------------------------------------------------------------------------------------------------
-- Demonstration 1: Brug parameter i en SP til at sikre SQL injection
-- -----------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE [ValidateLogin]
    @Name VARCHAR(100),
    @Password VARCHAR(100)
AS
    SELECT COUNT(*) FROM [users] WHERE [Name] = @Name AND [Password] = HASHBYTES('SHA2_512', @Password);
GO

-- Giv adgang til SP
GRANT EXECUTE ON [dbo].[ValidateLogin] TO [webtester];
GO

-- Test adgang som [webtester]
EXECUTE AS USER = 'webtester';
EXEC [dbo].[ValidateLogin] @Name = 'Mads', @Password = 'password'; -- Rigtigt, returnerer 1
EXEC [dbo].[ValidateLogin] @Name = 'Mads', @Password = 'hest'; -- Rigtigt, returnerer 0
EXEC [dbo].[ValidateLogin] @Name = 'Mads''--', @Password = 'hest'; -- Rigtigt, returnerer 0. SQL injection virker ikke
REVERT;
GO
-- -----------------------------------------------------------------------------------------------------
-- Demonstration 2: Brug dynamisk SQL uden parameter og se SQL injection virke
-- -----------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE [ValidateLoginInsecure]
    @Name VARCHAR(100),
    @Password VARCHAR(100)
AS
    DECLARE @SQL NVARCHAR(4000) = '';
    SELECT @SQL = 'SELECT COUNT(*) FROM [users] WHERE [Name] = ''' + @Name + ''' AND [Password] = HASHBYTES(''SHA2_512'',''' + @Password + ''')';
    PRINT @SQL;
    EXEC sp_executesql @SQL;
GO

GRANT EXECUTE ON [dbo].[ValidateLoginInsecure] TO [webtester];
GO

-- Test adgang som [webtester]
EXECUTE AS USER = 'webtester';
EXEC [dbo].[ValidateLoginInsecure] @Name = 'Mads', @Password = 'password'; -- Returnerer 1
EXEC [dbo].[ValidateLoginInsecure] @Name = 'Mads''--', @Password = 'password'; -- SQL injection succesfuld
EXEC [dbo].[ValidateLoginInsecure] @Name = 'Mads'';SELECT * FROM [secrets] --', @Password = 'password'; -- SQL injection succesfuld, men ikke adgang til [secrets]
REVERT;
GO
-- Resumé:
--     Lav en bruger, der ejer de SP'er, der skal afvikles og som har adgang til den data SP'en bruger.
--     Brug en anden bruger til at afvikle SP'erne, men som ikke har adgang til dataen SP'erne bruger.

-- -----------------------------------------------------------------------------------------------------
-- Demonstration 3: Få den oprindelige SP med parameter til at virke i det nye schema
-- -----------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE [www].[ValidateLoginWeb]
    @Name VARCHAR(100),
    @Password VARCHAR(100)
AS
    SELECT COUNT(*) FROM [users] WHERE [Name] = @Name AND [Password] = HASHBYTES('SHA2_512', @Password);
GO

GRANT EXECUTE ON [www].[ValidateLoginWeb] TO [webtester];
GO

-- Test adgang som [webtester]
EXECUTE AS USER = 'webtester';
EXEC [www].[ValidateLoginWeb] @Name = 'Mads', @Password = 'password'; --The SELECT permission was denied
EXEC [www].[ValidateLoginWeb] @Name = 'Mads''--', @Password = 'hest'; -- SQL injection virker ikke.
REVERT;
GO

-- Opdater SP til at afvikle som ejer
CREATE OR ALTER PROCEDURE [www].[ValidateLoginWeb]
    @Name VARCHAR(100),
    @Password VARCHAR(100)
WITH EXECUTE AS OWNER
AS
    SELECT COUNT(*) FROM [users] WHERE [Name] = @Name AND [Password] = HASHBYTES('SHA2_512', @Password);
GO

-- Prøv igen

-- Hvad er best practice?
