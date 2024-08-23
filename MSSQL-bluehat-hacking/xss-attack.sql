/************************************************************************************************/
--forebyg at der gemmes XSS attack i databasen
--eks.:
CREATE TABLE [homepageusers](
	[Id] [INT] IDENTITY(1,1) PRIMARY KEY,
	[Name] [varchar](100) NOT NULL,
	[Phone] [varchar](100) NOT NULL)
GO

--Problem:
INSERT INTO [homepageusers]([Name], [Phone]) 
VALUES ('<script>alert("unsafe & safe Utf8CharsDon''tGetEncoded ÄöÜ - Conex")</script>',
		'<script>alert(87654321)</script>')
--Dette vil potentielt returnere et java script direkte til browseren, hvor det vil blive afviklet
SELECT * FROM [homepageusers]

/************************************************************************************************/
--Metode 1 Brug de rigtig datatyper og gør dem så små som mulige.
--**Denne metode bør altid være en del af løsningen**
--Husk at dette typisk kræver specificering i krav specifikationen
DROP TABLE [homepageusers]
CREATE TABLE [homepageusers](
	[Id] [INT] IDENTITY(1,1) PRIMARY KEY,
	[Name] [varchar](40) NOT NULL,
	[Phone] [int] NOT NULL)
GO
INSERT INTO [homepageusers]([Name], [Phone]) 
VALUES ('<script>alert("unsafe")</script>', 87654321)
INSERT INTO [homepageusers]([Name], [Phone]) 
VALUES ('Navn Navnesen', 87654321)
--Det er stadig muligt med XSS, men mulighederne er blevet mindre
SELECT * FROM [homepageusers]

/************************************************************************************************/
--Metode 2 Tillad kun de tegn der skal bruges
ALTER TABLE [homepageusers]
ADD CONSTRAINT stdName CHECK([Name] NOT LIKE '%[^ A-Za-z]%');
--Første insert vil fejl da den indeholder andre chars end A-Za-z
INSERT INTO [homepageusers]([Name], [Phone]) 
VALUES ('<script>alert("unsafe")</script>',87654321)

--Fjern constraint. Nødvendig for de følgende metoder
ALTER TABLE [homepageusers]
DROP CONSTRAINT stdName

/************************************************************************************************/
--Metode 3 Hvis det skal være muligt at indsætte special tegn. Overvej at html encode feltet via en stored procedure
ALTER TABLE [homepageusers]
ALTER COLUMN [Name] varchar(50) NOT NULL
GO
CREATE OR ALTER PROCEDURE [AddWebUser]  
@Name AS VARCHAR(40),
@Phone AS INT WITH EXECUTE AS OWNER
AS 
BEGIN
	--validate param Name
	DECLARE @htmlEncode varchar(120)
	SELECT @htmlEncode = (SELECT @Name FOR XML PATH(''))
	PRINT @htmlEncode
	INSERT INTO [homepageusers] ([Name], [Phone]) VALUES (@htmlEncode, @Phone)
END
GO
--TEST
EXECUTE [AddWebUser] @Name = '<script>alert("unsafe")</script>', @Phone = 87654321
SELECT * FROM [homepageusers]
--Ulemper: der skal være en SP til update også. Det virker kun på det data der kommer igennem SP

/************************************************************************************************/
--Metode 4 en trigger på insert, update der encoder feltet...
ALTER TABLE [homepageusers]
ALTER COLUMN [Name] varchar(50) NOT NULL
GO
CREATE TRIGGER [homepageusersEncodeName]
ON [homepageusers] 
AFTER INSERT, UPDATE
AS
BEGIN
	UPDATE [homepageusers]
    SET [Name] = (SELECT i.[Name] AS [text()] FOR XML PATH(''))
    FROM [homepageusers]
    INNER JOIN inserted i on i.Id = [homepageusers].Id
END
GO

--test
INSERT INTO [homepageusers]([Name], [Phone]) 
VALUES ('<script>alert("unsafe")</script>',87654321)
SELECT * FROM [homepageusers]

UPDATE [homepageusers]
SET [Name] = '<script>alert("Hej")</script>'
WHERE [Id] = 1
SELECT * FROM [homepageusers]
GO
