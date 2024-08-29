-- Formål: POC for generering af dummy data for testning i MSSQL
-- Tip: Sørg for at afvikle kommandoerne en ad gangen for at forstå konsekvenserne.
-- Tip: Afprøv det på en testdatabase

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Afsnit: generering af talrække fra 1 til 5000000 i numbers
-- I borrowed this script from Aaron Bertrand at the following link https://sqlperformance.com/2013/01/t-sql-queries/generate-a-set-1.
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

SELECT [TOP] (5000000) [Number] = [CONVERT]([INT], [ROW_NUMBER]() [OVER] (
			ORDER BY s1.object_id
			))
INTO dbo.Numbers
FROM sys.all_objects AS s1
CROSS JOIN sys.all_objects AS s2;
GO

-- Se: 
SELECT * FROM dbo.Numbers;

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Afsnit: Opret nogle nye tabeller vi kan bruge til demonstrationen
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

CREATE TABLE [orders] (
	Id INT [IDENTITY] ([1],1),
	start_ts DATETIME not [null],
	end_ts [DATETIME],
	seats [INT],
	PRIMARY [KEY] (Id));
GO

CREATE TABLE [orderline] (
	Id INT [IDENTITY] ([1],1),
	OrderID INT not [null],
	paid [INT],
	PRIMARY [KEY] (Id),
    CONSTRAINT FK_OrderOrderline FOREIGN [KEY] (Id) REFERENCES [orderline](Id));
GO

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Afsnit: opret Dummy data orders
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
SET NOCOUNT ON;

-- insert 1000 orders
INSERT INTO [Orders] ( start_ts ) 
	SELECT [DATEADD]([HOUR],
		[RAND]([CHECKSUM]([NEWID]()))*8+[12],
		[DATEADD]([DAY], [RAND]([CHECKSUM]([NEWID]()))*([DATEDIFF]([DAY], '01/01/2024', '12/31/2024')),'01/01/2024')
		)AS OrderDate
	FROM dbo.Numbers n
	WHERE n.Number <= 1000;
GO
-- change end_ts til 2 timer efter start_ts
UPDATE orders SET [end_ts] = [DATEADD]([HOUR], [2], start_ts) WHERE end_ts is NULL;
GO

-- Se orders:
SELECT * FROM Orders;

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Afsnit: tilføj dummy orderlines til orders
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
SET NOCOUNT ON;
DECLARE @Order_ID int
DECLARE Order_cursor CURSOR FOR SELECT Id FROM [orders]
OPEN Order_cursor
FETCH NEXT FROM Order_cursor INTO @Order_ID

WHILE @@[FETCH_STATUS] = 0
BEGIN
	-- random number of seats
	DECLARE @seats int;
	SET @[seats] = [RAND]([CHECKSUM]([NEWID]()))*4
	IF @seats < 3
		SET @[seats] = 2+[RAND]([CHECKSUM]([NEWID]()))*3
	ELSE
		SET @[seats] = 5+[RAND]([CHECKSUM]([NEWID]()))*8
	-- update number of seats
	UPDATE orders SET [seats] = @seats WHERE [Id] = @Order_ID

	INSERT INTO [orderline](
		[OrderID],
		paid
		) 
	SELECT @[Order_ID],
			[CAST]([RAND]([CHECKSUM]([NEWID]()))*6 AS INT) *50+100 AS PAID
	FROM dbo.Numbers n
	WHERE n.Number <= @seats


	FETCH NEXT FROM Order_cursor INTO @Order_ID
END
CLOSE Order_cursor
DEALLOCATE Order_cursor
GO


SELECT [TOP](5) * FROM [orders];
SELECT [TOP](5) * FROM [orderline];

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Afsnit: Efter indsættelse af dummy [data], Vi nu kan bruge til at teste vores selects med
-- Nedenfor laver vi en select der give os omsætningen pr. dag for januar
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
DECLARE @month DATETIME
SET @[month] = '01/01/2024'

SELECT [CAST]([DATEADD]([DAY],n.[Number], @month)-1 AS DATE) as 'Date',
	[ISNULL]((SELECT [SUM](orderline.paid) FROM orders JOIN orderline ON orderline.[OrderID] = orders.Id WHERE [DATEDIFF]([DAY],orders.[start_ts], [DATEADD]([DAY],n.[Number], '01/01/2024')-1) = 0),0)
FROM dbo.Numbers n
WHERE n.Number <= 1+[DATEDIFF]([DAY], @[month], [DATEADD]([MONTH], [1], @month)-1);
