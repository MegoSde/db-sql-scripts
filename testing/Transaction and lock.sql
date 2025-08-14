--Test TRANSACTION, COMMIT AND ROLLBACK
--SETUP a test schema and table to use for testing
CREATE SCHEMA [TEST]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Test].[ValueTable]') AND type in (N'U'))
DROP TABLE [Test].[ValueTable]
GO
CREATE TABLE [Test].[ValueTable] (
id INT 
CONSTRAINT [PK_Test_ValueTable_Id] PRIMARY KEY ([Id])) 
GO
--Kør nedensående blok og se hvad der sker.
--Prøv at ændre den ene insert value til @currentId+2 og se hvad der sker
BEGIN TRY
	BEGIN TRANSACTION;
	PRINT 'Begin Transaction'
	DECLARE @currentId int;
	SELECT @currentId = MAX(id) FROM Test.ValueTable
	PRINT 'Next [Id] is ' + STR(@currentId+1)
	INSERT INTO Test.ValueTable VALUES(@currentId+1);  
    INSERT INTO Test.ValueTable VALUES(@currentId+1); --Will cast an exception and rollback. 
	COMMIT;
	PRINT 'Result: Commit';
END TRY
BEGIN CATCH  
    ROLLBACK;
	Print 'Result: Rollback';
	SELECT @currentId = MAX(id) FROM Test.ValueTable
	PRINT 'Next [Id] is ' + STR(@currentId+1)
END CATCH
GO

--Test af TABLE LOCK
--Åben et ekstra vindue, da de følgende sql'er skal køres efter hinanden
--SQL 1: Skal afvikles først
BEGIN TRANSACTION
DECLARE @currentId int
SELECT @currentId = MAX(id) FROM Test.ValueTable --WITH (TABLOCK, HOLDLOCK)
WAITFOR DELAY '0:00:10'
INSERT INTO Test.ValueTable VALUES(@currentId+1)
INSERT INTO Test.ValueTable VALUES(@currentId+2)
COMMIT
GO
--SQL 2: Skal afvikles i sit eget query vindue umildbart efter SQL 1 er startet.
INSERT INTO Test.ValueTable (id) SELECT MAX(id)+1 FROM Test.ValueTable
--Hvilken SQL fejler?
--Indkommenter "With (TABLOCK, HOLDLOCK)" og prøv igen.
