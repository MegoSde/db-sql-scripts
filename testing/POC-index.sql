/*
POC: Reservations - performance vs historik (MSSQL)

Formaal:
- Start med kun 3 maaneders FREMTIDIGE reservationer.
- Tilfoej derefter loebende HISTORIK (1 aar, 5 aar, 10 aar).
- Maal svartid/IO paa en query: "alle reservationer paa en bestemt dag i fremtiden".
- Se effekten af:
  (1) ingen index
  (2) almindeligt index paa StartTs
  (3) filtered index kun for fremtid (3 maaneder)

Korsel:
- Koer filen i STEPS (sektion for sektion).
- Naar du tester, koer gerne samme test 3-5 gange og tag typisk 2./3. koersel (cache).
*/

/* =========================
   STEP 1: Opret database
   ========================= */
IF DB_ID('POC_Reservations') IS NULL
BEGIN
    CREATE DATABASE POC_Reservations;
END
GO
USE POC_Reservations;
GO

/* =========================
   STEP 2: Numbers tabel (set-based generator)
   - Opret hvis den ikke findes.
   - 5 mio rækker er rigeligt til mange POC'er.
   ========================= */
IF OBJECT_ID('dbo.Numbers','U') IS NULL
BEGIN
    CREATE TABLE dbo.Numbers
    (
        Number INT NOT NULL CONSTRAINT PK_Numbers PRIMARY KEY
    );

    ;WITH n AS
    (
        SELECT TOP (5000000)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS num
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
    )
    INSERT INTO dbo.Numbers(Number)
    SELECT num FROM n;
END
GO

/* =========================
   STEP 3: Opret Reservation tabel
   ========================= */
DROP TABLE IF EXISTS dbo.Reservation;
GO

CREATE TABLE dbo.Reservation
(
    ReservationId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Reservation PRIMARY KEY,
    StartTs       DATETIME2(0) NOT NULL,
    EndTs         DATETIME2(0) NOT NULL,
    Seats         TINYINT      NOT NULL,
    CustomerName  NVARCHAR(80) NOT NULL,
    Phone         NVARCHAR(20) NULL,
    CreatedAt     DATETIME2(0) NOT NULL CONSTRAINT DF_Reservation_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

/* =========================
   STEP 4: Generator procedure
   - @StartDate inklusiv
   - @EndDate eksklusiv
   - @PerDay reservationer pr dag
   ========================= */
CREATE OR ALTER PROCEDURE dbo.GenerateReservations
    @StartDate DATE,
    @EndDate   DATE,
    @PerDay    INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Days INT = DATEDIFF(DAY, @StartDate, @EndDate);
    IF @Days <= 0 THROW 50000, 'EndDate must be after StartDate', 1;
    IF @PerDay <= 0 THROW 50001, 'PerDay must be > 0', 1;

    ;WITH d AS
    (
        SELECT TOP (@Days)
               DayOffset = n.Number - 1
        FROM dbo.Numbers n
        ORDER BY n.Number
    ),
    r AS
    (
        SELECT TOP (@Days * @PerDay)
               RowNum = n.Number
        FROM dbo.Numbers n
        ORDER BY n.Number
    ),
    x AS
    (
        SELECT
            DayDate = DATEADD(DAY, d.DayOffset, @StartDate),
            RowNum  = r.RowNum
        FROM d
        JOIN r
          ON r.RowNum BETWEEN d.DayOffset * @PerDay + 1 AND (d.DayOffset + 1) * @PerDay
    )
    INSERT INTO dbo.Reservation (StartTs, EndTs, Seats, CustomerName, Phone)
    SELECT
        StartTs =
            DATEADD(MINUTE,
                (ABS(CHECKSUM(NEWID())) % (10*60 + 30)) + (11*60),  -- 11:00 to 21:30
                CAST(x.DayDate AS DATETIME2(0))
            ),
        EndTs =
            DATEADD(MINUTE,
                (ABS(CHECKSUM(NEWID())) % 121) + 60,                -- 60 to 180 min
                DATEADD(MINUTE,
                    (ABS(CHECKSUM(NEWID())) % (10*60 + 30)) + (11*60),
                    CAST(x.DayDate AS DATETIME2(0))
                )
            ),
        Seats = CAST((ABS(CHECKSUM(NEWID())) % 8) + 1 AS TINYINT),
        CustomerName = CONCAT(N'Customer ', ABS(CHECKSUM(NEWID())) % 1000000),
        Phone = CONCAT(N'+45', RIGHT(CONCAT('00000000', ABS(CHECKSUM(NEWID())) % 100000000), 8))
    FROM x;
END
GO

/* =========================
   STEP 5: Seed KUN 3 maaneders fremtid
   Vigtigt:
   - Vi bruger faste datoer, saa alle elever faar samme datamaengde.
   - Skift disse datoer hvis du vil "flytte nu".
   ========================= */
DECLARE @StartDate date;
DECLARE @EndDate date;

SET @StartDate = '2026-01-20';
SET @EndDate   = '2026-04-20';

EXEC dbo.GenerateReservations
    @StartDate = @StartDate,
    @EndDate   = @EndDate,
    @PerDay    = 300;
GO

/* =========================
   STEP 6: Test-query (baseline)
   - Hent alle reservationer paa EN dag i fremtiden.
   - Maal med STATISTICS IO/TIME.
   - Koer gerne samme test 3-5 gange.
   ========================= */
DECLARE @TestDay date;
DECLARE @From datetime2(0);
DECLARE @To datetime2(0);

SET @TestDay = '2026-02-15';
SET @From = CAST(@TestDay AS datetime2(0));
SET @To   = DATEADD(DAY, 1, @From);

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT ReservationId, StartTs, EndTs, Seats, CustomerName
FROM dbo.Reservation
WHERE StartTs >= @From
  AND StartTs <  @To
ORDER BY StartTs;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

/* =========================
   STEP 7: Tilfoej 1 aars historik (kun fortid)
   - Nu har vi stadig kun 3 maaneder fremtid,
     men vi begynder at fylde historik paa.
   ========================= */
DECLARE @HistStart date;
DECLARE @HistEnd date;

SET @HistStart = '2025-01-20';
SET @HistEnd   = '2026-01-20';

EXEC dbo.GenerateReservations
    @StartDate = @HistStart,
    @EndDate   = @HistEnd,
    @PerDay    = 300;
GO

/* =========================
   STEP 8: Test igen (efter 1 aars historik)
   ========================= */
DECLARE @TestDay2 date;
DECLARE @From2 datetime2(0);
DECLARE @To2 datetime2(0);

SET @TestDay2 = '2026-02-15';
SET @From2 = CAST(@TestDay2 AS datetime2(0));
SET @To2   = DATEADD(DAY, 1, @From2);

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT ReservationId, StartTs, EndTs, Seats, CustomerName
FROM dbo.Reservation
WHERE StartTs >= @From2
  AND StartTs <  @To2
ORDER BY StartTs;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

/* =========================
   STEP 9: Udvid historik til 5 aar total (tilfoej yderligere 4 aar)
   ========================= */
DECLARE @HistStart5 date;
DECLARE @HistEnd5 date;

SET @HistStart5 = '2021-01-20';
SET @HistEnd5   = '2025-01-20';

EXEC dbo.GenerateReservations
    @StartDate = @HistStart5,
    @EndDate   = @HistEnd5,
    @PerDay    = 300;
GO

/* =========================
   STEP 10: Test igen (efter 5 aars historik)
   ========================= */
DECLARE @TestDay3 date;
DECLARE @From3 datetime2(0);
DECLARE @To3 datetime2(0);

SET @TestDay3 = '2026-02-15';
SET @From3 = CAST(@TestDay3 AS datetime2(0));
SET @To3   = DATEADD(DAY, 1, @From3);

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT ReservationId, StartTs, EndTs, Seats, CustomerName
FROM dbo.Reservation
WHERE StartTs >= @From3
  AND StartTs <  @To3
ORDER BY StartTs;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

/* =========================
   STEP 11: Opret almindeligt index paa StartTs
   - Forbedrer typisk future-queries, men index kan blive stort naar historik vokser.
   ========================= */
DROP INDEX IF EXISTS IX_Reservation_StartTs ON dbo.Reservation;
GO
CREATE INDEX IX_Reservation_StartTs
ON dbo.Reservation (StartTs)
INCLUDE (EndTs, Seats, CustomerName);
GO

/* =========================
   STEP 12: Test igen (med almindeligt index) + index stoerrelse
   ========================= */
DECLARE @TestDay4 date;
DECLARE @From4 datetime2(0);
DECLARE @To4 datetime2(0);

SET @TestDay4 = '2026-02-15';
SET @From4 = CAST(@TestDay4 AS datetime2(0));
SET @To4   = DATEADD(DAY, 1, @From4);

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT ReservationId, StartTs, EndTs, Seats, CustomerName
FROM dbo.Reservation
WHERE StartTs >= @From4
  AND StartTs <  @To4
ORDER BY StartTs;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

-- Index size (MB)
SELECT
    i.name AS IndexName,
    i.type_desc,
    SUM(a.total_pages) * 8 / 1024.0 AS TotalMB,
    SUM(a.used_pages)  * 8 / 1024.0 AS UsedMB,
    MAX(p.rows) AS RowCounter
FROM sys.indexes i
JOIN sys.partitions p
  ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.allocation_units a
  ON a.container_id = p.partition_id
WHERE i.object_id = OBJECT_ID('dbo.Reservation')
GROUP BY i.name, i.type_desc
ORDER BY TotalMB DESC;
GO
  
/* =========================
   STEP 13: Udvid historik til 10 aar total (tilfoej yderligere 5 aar)
   ========================= */
DECLARE @HistStart10 date;
DECLARE @HistEnd10 date;

SET @HistStart10 = '2016-01-20';
SET @HistEnd10   = '2021-01-20';

EXEC dbo.GenerateReservations
    @StartDate = @HistStart10,
    @EndDate   = @HistEnd10,
    @PerDay    = 300;
GO

/* =========================
   STEP 14: Test igen (10 aars historik) + index stoerrelse
   ========================= */
DECLARE @TestDay5 date;
DECLARE @From5 datetime2(0);
DECLARE @To5 datetime2(0);

SET @TestDay5 = '2026-02-15';
SET @From5 = CAST(@TestDay5 AS datetime2(0));
SET @To5   = DATEADD(DAY, 1, @From5);

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT ReservationId, StartTs, EndTs, Seats, CustomerName
FROM dbo.Reservation
WHERE StartTs >= @From5
  AND StartTs <  @To5
ORDER BY StartTs;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT
    i.name AS IndexName,
    i.type_desc,
    SUM(a.total_pages) * 8 / 1024.0 AS TotalMB,
    SUM(a.used_pages)  * 8 / 1024.0 AS UsedMB,
    MAX(p.rows) AS RowCounter
FROM sys.indexes i
JOIN sys.partitions p
  ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.allocation_units a
  ON a.container_id = p.partition_id
WHERE i.object_id = OBJECT_ID('dbo.Reservation')
GROUP BY i.name, i.type_desc
ORDER BY TotalMB DESC;
GO

/* =========================
   STEP 15: Skift til filtered index (kun 3 maaneder fremtid)
   Vigtigt:
   - Filtered index er en "bevidst designbeslutning":
     vi optimerer til queries paa fremtid, fordi historik sjeldent er svartidskritisk.
   - Vi bruger faste datoer som matcher vores seed-fremtid.
   ========================= */
DROP INDEX IF EXISTS IX_Reservation_StartTs ON dbo.Reservation;
DROP INDEX IF EXISTS IX_Reservation_Future_StartTs ON dbo.Reservation;
GO

CREATE INDEX IX_Reservation_Future_StartTs
ON dbo.Reservation (StartTs)
INCLUDE (EndTs, Seats, CustomerName)
WHERE StartTs >= '2026-01-20'
  AND StartTs <  '2026-04-20';
GO

/* =========================
   STEP 16: Test igen (filtered index) + index stoerrelse
   ========================= */
DECLARE @TestDay6 date;
DECLARE @From6 datetime2(0);
DECLARE @To6 datetime2(0);

SET @TestDay6 = '2026-02-15';
SET @From6 = CAST(@TestDay6 AS datetime2(0));
SET @To6   = DATEADD(DAY, 1, @From6);

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT ReservationId, StartTs, EndTs, Seats, CustomerName
FROM dbo.Reservation
WHERE StartTs >= @From6
  AND StartTs <  @To6
ORDER BY StartTs;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT
    i.name AS IndexName,
    i.type_desc,
    SUM(a.total_pages) * 8 / 1024.0 AS TotalMB,
    SUM(a.used_pages)  * 8 / 1024.0 AS UsedMB,
    MAX(p.rows) AS RowCounter
FROM sys.indexes i
JOIN sys.partitions p
  ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.allocation_units a
  ON a.container_id = p.partition_id
WHERE i.object_id = OBJECT_ID('dbo.Reservation')
GROUP BY i.name, i.type_desc
ORDER BY TotalMB DESC;
GO

/* =========================
   STEP 17 (valgfri): Konklusion / refleksion
   Svar kort:
   - Hvad skete der med IO/TIME naar historik voksede?
   - Hvor meget voksede det almindelige index?
   - Hvorfor blev filtered index mindre?
   - Hvilke trade-offs er der ved filtered index?
   ========================= */

/*
APPENDIX / FORLÆNGELSE: Execution plan + filtered index + in_future-model
Forudsætning:
- I har kørt alle den ovenstående

Mål:
A) Vis at optimizer kan IGNORERE filtered index når query kun bruger parametre
B) Vis at "explicit periode" får Index Seek på filtered index
C) Forklar TODAY/NOW-problemet kort
D) Implementer in_future kolonne + SP der vedligeholder den
E) Filtered index på in_future=1 + test/plan
*/


/* =========================
   STEP A2: Faktisk plan (PROFILE) - query KUN med parametre
   Forventning:
   - Ofte Clustered Index Scan, fordi SQL Server ikke kan bevise at @From/@To er indenfor filteret
   ========================= */
DECLARE @TestDay date;
DECLARE @From datetime2(0);
DECLARE @To datetime2(0);

SET @TestDay = '2026-02-15';
SET @From = CAST(@TestDay AS datetime2(0));
SET @To   = DATEADD(DAY, 1, @From);

SET STATISTICS PROFILE ON;

SELECT ReservationId, StartTs, EndTs, Seats, CustomerName
FROM dbo.Reservation
WHERE StartTs >= @From
  AND StartTs <  @To
ORDER BY StartTs;

SET STATISTICS PROFILE OFF;
GO

/* =========================
   STEP A3: Faktisk plan (PROFILE) - "fix" query med explicit periode
   Forventning:
   - Index Seek på IX_Reservation_Future_StartTs
   ========================= */
SET STATISTICS PROFILE ON;

DECLARE @TestDay date;
DECLARE @From datetime2(0);
DECLARE @To datetime2(0);

SET @TestDay = '2026-02-15';
SET @From = CAST(@TestDay AS datetime2(0));
SET @To   = DATEADD(DAY, 1, @From);

SELECT ReservationId, StartTs, EndTs, Seats, CustomerName
FROM dbo.Reservation
WHERE StartTs >= @From
  AND StartTs <  @To
  AND StartTs >= '2026-01-20'
  AND StartTs <  '2026-04-20'
ORDER BY StartTs;

SET STATISTICS PROFILE OFF;
GO

/* =========================
   STEP B: Kort skriv om TODAY/NOW problemstillingen (til rapport)
   - SQL Server tillader ikke GETDATE()/SYSUTCDATETIME() i et filtered index filter
   - fordi det er ikke-deterministisk og ville ændre hvilke rækker der "hører til" hvert sekund.
   - Derfor bruger man typisk en flag-kolonne + job/SP der opdaterer den dagligt.
   ========================= */

/* =========================
   STEP C1: Tilføj in_future kolonne (produktionsnaer model)
   - Default TRUE (1)
   - Vi vedligeholder den via en procedure
   ========================= */
IF COL_LENGTH('dbo.Reservation', 'in_future') IS NULL
BEGIN
    ALTER TABLE dbo.Reservation
    ADD in_future bit NOT NULL
        CONSTRAINT DF_Reservation_in_future DEFAULT (1);
END
GO

/* =========================
   STEP C2: SP der sætter gamle reservationer til in_future = 0
   - Køres typisk én gang i døgnet (fx lige efter midnat)
   ========================= */
CREATE OR ALTER PROCEDURE dbo.RefreshInFutureFlag
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today date;
    SET @Today = CONVERT(date, SYSUTCDATETIME());

    -- alt før i dag -> historik
    UPDATE dbo.Reservation
    SET in_future = 0
    WHERE StartTs < CAST(@Today AS datetime2(0))
      AND in_future = 1;

    -- alt fra i dag og frem -> future
    UPDATE dbo.Reservation
    SET in_future = 1
    WHERE StartTs >= CAST(@Today AS datetime2(0))
      AND in_future = 0;
END
GO

EXEC dbo.RefreshInFutureFlag;
GO

/* =========================
   STEP C3: Filtered index på in_future = 1
   - Nu er filteret stabilt (det afhænger ikke af NOW)
   ========================= */
DROP INDEX IF EXISTS IX_Reservation_FutureFlag_StartTs ON dbo.Reservation;
DROP INDEX IF EXISTS IX_Reservation_Future_StartTs ON dbo.Reservation;
GO

CREATE INDEX IX_Reservation_FutureFlag_StartTs
ON dbo.Reservation (StartTs)
INCLUDE (EndTs, Seats, CustomerName)
WHERE in_future = 1;
GO

UPDATE STATISTICS dbo.Reservation WITH FULLSCAN;
GO

/* =========================
   STEP C4: Faktisk plan (PROFILE) - query med in_future = 1
   Forventning:
   - Index Seek på IX_Reservation_FutureFlag_StartTs
   ========================= */
DECLARE @TestDay date;
DECLARE @From datetime2(0);
DECLARE @To datetime2(0);

SET @TestDay = '2026-02-15';
SET @From = CAST(@TestDay AS datetime2(0));
SET @To   = DATEADD(DAY, 1, @From);

SET STATISTICS PROFILE ON;

SELECT ReservationId, StartTs, EndTs, Seats, CustomerName
FROM dbo.Reservation
WHERE in_future = 1
  AND StartTs >= @From
  AND StartTs <  @To
ORDER BY StartTs;

SET STATISTICS PROFILE OFF;
GO

/* =========================
   STEP C5: Index-størrelse (MB) til rapport
   ========================= */
SELECT
    i.name AS IndexName,
    i.type_desc,
    i.has_filter,
    i.filter_definition,
    SUM(a.total_pages) * 8 / 1024.0 AS TotalMB,
    SUM(a.used_pages)  * 8 / 1024.0 AS UsedMB,
    MAX(p.rows) AS RowCounter
FROM sys.indexes i
JOIN sys.partitions p
  ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.allocation_units a
  ON a.container_id = p.partition_id
WHERE i.object_id = OBJECT_ID('dbo.Reservation')
GROUP BY i.name, i.type_desc, i.has_filter, i.filter_definition
ORDER BY TotalMB DESC;
GO
