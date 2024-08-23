--Login som dbo
--Lav to tabeller med data som udgangspunkt
CREATE table [users] (
	[Name] varchar(100) PRIMARY KEY, 
	[Password] varbinary(100) )
INSERT INTO [users]([Name],[Password]) VALUES ('Mads', HASHBYTES('SHA2_512', 'password'));

CREATE table [secrets] (
	[Text] varchar(100))
INSERT INTO [secrets]([Text]) VALUES ('Hemmelighed');
--Create a test user

CREATE USER [webtester] WITHOUT LOGIN WITH DEFAULT_SCHEMA=[dbo]
GO

--Viser hvad der er lagt ind
SELECT * FROM [users];
SELECT * FROM [secrets];
GO
--Test 1.
--Lav en SP der benytter parameter
CREATE OR ALTER PROCEDURE ValidateLogin
	@Name VARCHAR(100),
	@Password VARCHAR(100)
AS
	SELECT count(*) FROM [users] WHERE [Name] = @Name AND [Password] = HASHBYTES('SHA2_512', @Password)
GO

--Giv adgang til SP
GRANT EXECUTE ON dbo.ValidateLogin TO [webtester]
--test adgang som webtester
EXECUTE AS USER = 'webtester'

EXEC dbo.ValidateLogin @Name = 'Mads', @Password = 'password' --Rigtig, return 1
EXEC dbo.ValidateLogin @Name = 'Mads', @Password = 'hest' --Rigtig, return 0
EXEC dbo.ValidateLogin @Name = 'Mads''--', @Password = 'hest' --Rigtig, return 0 SQL injection virker ikke

REVERT
GO

--Test 2. Lav en usikker SP
CREATE OR ALTER PROCEDURE ValidateLoginSQL
	@Name VARCHAR(100),
	@Password VARCHAR(100) 
AS
	DECLARE @SQL NVARCHAR(4000) = '';
	SELECT @SQL = 'SELECT COUNT(*) FROM [users] WHERE [Name] = ''' + @Name + ''' AND [Password] = HASHBYTES(''SHA2_512'',''' + @Password + ''')';
	PRINT @SQL
    EXEC sp_executesql @SQL;
GO
--test at der kan laves sql injection
EXEC ValidateLoginSQL @Name = 'Mads''--', @Password = 'hest' --Usikker, return 1 SQL injection er en succes
GO
--Giv adgang til SP
GRANT EXECUTE ON dbo.ValidateLoginSQL TO [webtester]
--test adgang som webtester
EXECUTE AS USER = 'webtester'

EXEC dbo.ValidateLoginSQL @Name = 'Mads', @Password = 'password' --return: The SELECT permission was denied

REVERT
GO
--Vi kan løse ovenstående ved at give webtester select adgang til users
GRANT SELECT ON dbo.[users] TO [webtester]
--prøv igen
--men nu er følgende også muligt!
EXECUTE AS USER = 'webtester'
SELECT * FROM [users]
REVERT
--Det er ikke meningen så lad os revoke rettighederne igen.
REVOKE SELECT ON dbo.[users] TO [webtester]

--Test 3 EXECUTE SP as OWNER
CREATE OR ALTER PROCEDURE ValidateLoginAsOwner
	@Name VARCHAR(100),
	@Password VARCHAR(100) WITH EXECUTE AS OWNER
AS
	DECLARE @SQL NVARCHAR(4000) = '';
	SELECT @SQL = 'SELECT COUNT(*) FROM [users] WHERE [Name] = ''' + @Name + ''' AND [Password] = HASHBYTES(''SHA2_512'',''' + @Password + ''')';
	PRINT @SQL
    EXEC sp_executesql @SQL;
GO
GRANT EXECUTE ON dbo.ValidateLoginAsOwner TO [webtester]
--test adgang som webtester
EXECUTE AS USER = 'webtester'

EXEC dbo.ValidateLoginAsOwner @Name = 'Mads', @Password = 'password' --rigtig: return 1
EXEC dbo.ValidateLoginAsOwner @Name = 'Mads'';SELECT * FROM [secrets] --', @Password = 'password' --rigtig. SQL injection succesfull

REVERT

--Test 4 Lav et schema der er ejet af sin egen bruger, der kun har de rettigheder den skal bruge
GO
create schema www
GO
ALTER USER webtester WITH DEFAULT_SCHEMA = www

CREATE USER ApiExec WITHOUT LOGIN WITH DEFAULT_SCHEMA = www; 
ALTER AUTHORIZATION ON SCHEMA::www TO ApiExec;
GRANT SELECT ON dbo.[users] TO ApiExec
GO
CREATE OR ALTER PROCEDURE www.ValidateLoginWWW
	@Name VARCHAR(100),
	@Password VARCHAR(100) WITH EXECUTE AS OWNER
AS
	DECLARE @SQL NVARCHAR(4000) = '';
	SELECT @SQL = 'SELECT COUNT(*) FROM [users] WHERE [Name] = ''' + @Name + ''' AND [Password] = HASHBYTES(''SHA2_512'',''' + @Password + ''')';
	PRINT @SQL
    EXEC sp_executesql @SQL;
GO
GRANT EXECUTE ON www.ValidateLoginWWW TO webtester
GO
--test adgang som webtester
EXECUTE AS USER = 'webtester'

EXEC www.ValidateLoginWWW @Name = 'Mads', @Password = 'password' --return 1
EXEC www.ValidateLoginWWW @Name = 'Mads''--', @Password = 'password' --SQL injection succesfull
EXEC www.ValidateLoginWWW @Name = 'Mads'';SELECT * FROM [secrets] --', @Password = 'password' -- SQL injection succesfull...men ikke adgang til secrets

REVERT
GO
--Test 5 SP med parameter i det nye schema
CREATE OR ALTER PROCEDURE www.ValidateLoginWeb
	@Name VARCHAR(100),
	@Password VARCHAR(100)
AS
	SELECT count(*) FROM [users] WHERE [Name] = @Name AND [Password] = HASHBYTES('SHA2_512', @Password)
GO
GRANT EXECUTE ON www.ValidateLoginWeb TO webtester
GO
--test adgang som webtester
EXECUTE AS USER = 'webtester'

EXEC www.ValidateLoginWeb @Name = 'Mads', @Password = 'password' --The SELECT permission was denied
EXEC www.ValidateLoginWeb @Name = 'Mads''--', @Password = 'hest' --SQL injection virker ikke.

REVERT
GO
--update SP to execute as owner
CREATE OR ALTER PROCEDURE www.ValidateLoginWeb
	@Name VARCHAR(100),
	@Password VARCHAR(100)  WITH EXECUTE AS OWNER
AS
	SELECT count(*) FROM [users] WHERE [Name] = @Name AND [Password] = HASHBYTES('SHA2_512', @Password)
GO
--Prøv igen

--Hvad er best practice?