-- Formål: Demonstrere sårbarheden for XSS-attack i en MSSQL-database
-- Tip: Sørg for at afvikle kommandoerne en ad gangen for at forstå konsekvenserne.

-- -----------------------------------------------------------------------------------------------------
-- Afsnit: Oprettelse af testdatabase
-- Vi starter med at oprette en ny testdatabase for at sikre, at ingen eksisterende data kompromitteres.
-- -----------------------------------------------------------------------------------------------------
CREATE DATABASE [POC_XSS_TestDB];
USE [POC_XSS_TestDB];

-- -----------------------------------------------------------------------------------------------------
-- Udgangspunkt: Oprettelse af en tabel med en potentiel XSS-sårbarhed
-- Tabellen [homepageusers] oprettes med en kolonne til kommentarer, hvor XSS-angreb kan udføres.
-- Vigtigt: Dette alle metoder tager udgangspunkt i dette udgangspunkt!
-- -----------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS [homepageusers];
CREATE TABLE [homepageusers] (
    [Id] INT IDENTITY(1,1) PRIMARY KEY,
    [Name] VARCHAR(100) NOT NULL,
    [Phone] VARCHAR(100) NOT NULL
);

-- -----------------------------------------------------------------------------------------------------
-- Problemstilling: Demonstration af problemmet
-- -----------------------------------------------------------------------------------------------------
INSERT INTO [homepageusers] ([Name], [Phone]) 
VALUES ('<script>alert("unsafe & safe Utf8CharsDon''tGetEncoded ÄöÜ - Conex")</script>',
		'<script>alert(87654321)</script>');

-- Dette vil potentielt returnere et java script direkte til browseren, hvor det vil blive afviklet
SELECT * FROM [homepageusers];

-- -----------------------------------------------------------------------------------------------------
-- Metode 1: Brug de rigtige datatyper og gør dem så små som mulige.
-- Tip: Denne metode bør altid være en del af løsningen
-- Husk: at dette typisk kræver specificering i kravspecifikationen
-- -----------------------------------------------------------------------------------------------------
-- Dette bliver det nye udgangspunkt...

DROP TABLE IF EXISTS [homepageusers];
CREATE TABLE [homepageusers] (
	[Id] INT IDENTITY(1,1) PRIMARY KEY,
	[Name] VARCHAR(50) NOT NULL,
	[Phone] INT NOT NULL
);

-- Test: 
INSERT INTO [homepageusers] ([Name], [Phone]) 
VALUES 
    ('<script>alert("unsafe")</script>', 87654321),
    ('Navn Navnesen', 87654321);
   
-- Det er stadig muligt med XSS, men mulighederne er blevet mindre, forsøg også med tidligere inserts
SELECT * FROM [homepageusers];

-- -----------------------------------------------------------------------------------------------------
-- Metode 2: Tillad kun de tegn der skal bruges
-- drop table og opret igen fra det nye udgangspunkt
-- -----------------------------------------------------------------------------------------------------

ALTER TABLE [homepageusers]
ADD CONSTRAINT [stdName] CHECK ([Name] NOT LIKE '%[^ A-Za-z]%');

-- Første insert vil fejl da den indeholder andre tegn end A-Za-z
INSERT INTO [homepageusers] ([Name], [Phone]) 
VALUES ('<script>alert("unsafe")</script>', 87654321);

-- Anden insert vil stadig virke
INSERT INTO [homepageusers] ([Name], [Phone]) 
VALUES ('Navn navnesen', 87654321);

SELECT * FROM [homepageusers];

-- Fjern constraint. Nødvendig for de følgende metoder
ALTER TABLE [homepageusers]
DROP CONSTRAINT [stdName];

-- Ulempe: Specialtegn er ikke tilladt

-- -----------------------------------------------------------------------------------------------------
-- Metode 3: Hvis det skal være muligt at indsætte specialtegn. Overvej at html-encode feltet via en stored procedure
-- drop table og opret igen fra det nye udgangspunkt
-- Desværre er det ikke alle databaser, der har en indbygget måde til at håndtere html encoding
-- De fleste steder foreslås det at håndtere XSS på application layer. Dog kan jeg godt lide at DB er ansvarlig for dataen
-- -----------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE [AddWebUser]  
@Name AS VARCHAR(40),
@Phone AS INT WITH EXECUTE AS OWNER
AS 
BEGIN
	-- Validate param Name
	DECLARE @htmlEncode VARCHAR(120);
	SELECT @htmlEncode = (SELECT @Name FOR XML PATH(''));
	INSERT INTO [homepageusers] ([Name], [Phone]) VALUES (@htmlEncode, @Phone);
END;

-- TEST
EXECUTE [AddWebUser] @Name = '<script>alert("unsafe")</script>', @Phone = 87654321;
SELECT * FROM [homepageusers];

-- Ulemper: Der skal være en SP til update også. Det virker kun på det data, der kommer igennem SP

-- -----------------------------------------------------------------------------------------------------
-- Metode 4: En trigger på insert, update der encoder feltet...
-- drop table og opret igen fra det nye udgangspunkt
-- Samme udfordring med html encoding som i metode 3
-- -----------------------------------------------------------------------------------------------------

ALTER TABLE [homepageusers]
ALTER COLUMN [Name] VARCHAR(70) NOT NULL;

CREATE OR ALTER TRIGGER [homepageusersEncodeName]
ON [homepageusers] 
AFTER INSERT, UPDATE
AS
BEGIN
    -- Update only if the Name column is being inserted or updated
    IF UPDATE([Name])
    BEGIN
        UPDATE h
        SET h.[Name] = (SELECT i.[Name] AS [text()] FOR XML PATH(''))
        FROM [homepageusers] h
        INNER JOIN inserted i ON i.[Id] = h.[Id]
        WHERE i.[Name] IS NOT NULL;
    END;
END;

-- TEST 
INSERT INTO [homepageusers] ([Name], [Phone]) 
VALUES ('<script>alert("unsafe")</script>', 87654321);

UPDATE [homepageusers]
SET [Phone] = 12345678
WHERE [Id] = 1;

UPDATE [homepageusers]
SET [Name] = '<script>alert("XSS")</script>', [Phone] = 56781234
WHERE [Id] = 1;

SELECT * FROM [homepageusers];


-- -----------------------------------------------------------------------------------------------------
-- Oprydning
-- -----------------------------------------------------------------------------------------------------
USE [master];
DROP DATABASE [POC_XSS_TestDB];
