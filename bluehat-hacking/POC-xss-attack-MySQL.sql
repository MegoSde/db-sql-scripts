-- Formål: Demonstrere sårbarheden for XSS-attack i en MSSQL-database
-- Tip: Sørg for at afvikle kommandoerne en ad gangen for at forstå konsekvenserne.

-- -----------------------------------------------------------------------------------------------------
-- Afsnit: Oprettelse af testdatabase
-- Vi starter med at oprette en ny testdatabase for at sikre, at ingen eksisterende data kompromitteres.
-- -----------------------------------------------------------------------------------------------------
CREATE DATABASE `POC_XSS_TestDB`;
-- Forbind til den nye database `POC_XSS_TestDB`

-- -----------------------------------------------------------------------------------------------------
-- Udgangspunkt: Oprettelse af en tabel med en potentiel XSS-sårbarhed
-- Tabellen `UserComments` oprettes med en kolonne til kommentarer, hvor XSS-angreb kan udføres.
-- Vigtigt: Dette alle metoder tager udgangspunkt i dette udgangspunkt!
-- -----------------------------------------------------------------------------------------------------

-- MySQL
DROP TABLE IF EXISTS `homepageusers`;
CREATE TABLE `homepageusers` (
    `Id` INT PRIMARY KEY AUTO_INCREMENT,
    `Name` VARCHAR(100) NOT NULL,
    `Phone` VARCHAR(100) NOT NULL
);

-- -----------------------------------------------------------------------------------------------------
-- Problemstilling: Demonstration af problemmet
-- -----------------------------------------------------------------------------------------------------

INSERT INTO `homepageusers`(`Name`, `Phone`) 
VALUES ('<script>alert("unsafe & safe Utf8CharsDon''tGetEncoded ÄöÜ - Conex")</script>',
		'<script>alert(87654321)</script>');
-- Dette vil potentielt returnere et java script direkte til browseren, hvor det vil blive afviklet
SELECT * FROM `homepageusers`;

-- -----------------------------------------------------------------------------------------------------
-- Metode 1 Brug de rigtige datatyper og gør dem så små som mulige.
-- Tip: Denne metode bør altid være en del af løsningen
-- Husk: at dette typisk kræver specificering i kravspecifikationen
-- -----------------------------------------------------------------------------------------------------
-- Dette bliver det nye udgangspunkt...

-- MySQL
DROP TABLE IF EXISTS `homepageusers`;
CREATE TABLE `homepageusers` (
    `Id` INT PRIMARY KEY AUTO_INCREMENT,
    `Name` VARCHAR(50) NOT NULL,
    `Phone` INT NOT NULL
);

INSERT INTO `homepageusers`(`Name`, `Phone`) 
VALUES 
    ('<script>alert("unsafe")</script>', 87654321),
    ('Navn Navnesen', 87654321);
   
-- Det er stadig muligt med XSS, men mulighederne er blevet mindre, forsøg også med tidligere inserts
SELECT * FROM `homepageusers`;

-- -----------------------------------------------------------------------------------------------------
-- Metode 2 Tillad kun de tegn der skal bruges
-- Vigtig! Drop table og opret igen fra det nye udgangspunkt
-- -----------------------------------------------------------------------------------------------------

ALTER TABLE `homepageusers`
ADD CONSTRAINT `stdName` CHECK (`Name` REGEXP '^[A-Za-z ]+$');

-- Første insert vil fejl da den indeholder andre chars end A-Za-z
INSERT INTO `homepageusers`(`Name`, `Phone`) 
VALUES ('<script>alert("unsafe")</script>',87654321);
-- Anden insert vil stadig virke.
INSERT INTO `homepageusers`(`Name`, `Phone`) 
VALUES ('Navn navnesen',87654321);

SELECT * FROM `homepageusers`;

-- Fjern constraint. Nødvendig for de følgende metoder
ALTER TABLE `homepageusers`
DROP CONSTRAINT `stdName`;

-- Ulempe: Specialtegn er ikke tilladt

-- -----------------------------------------------------------------------------------------------------
-- Metode 3 Hvis det skal være muligt at indsætte specialtegn. Overvej at HTML encode feltet via en stored procedure
-- Drop table og opret igen fra det nye udgangspunkt
-- Desværre er det ikke alle database der har en indbygget måde til at håndtere HTML encode
-- De fleste steder foreslåes det at håndtere XSS på application layer. Dog kan jeg godt lide at DB er ansvarlig for dataen
-- -----------------------------------------------------------------------------------------------------

ALTER TABLE `homepageusers`
MODIFY COLUMN `Name` VARCHAR(70) NOT NULL;

DROP FUNCTION IF EXISTS `html_encode`;

DELIMITER //
CREATE FUNCTION `html_encode`(input TEXT) 
RETURNS TEXT
DETERMINISTIC
BEGIN
    SET input = REPLACE(input, '&', '&amp;');
    SET input = REPLACE(input, '<', '&lt;');
    SET input = REPLACE(input, '>', '&gt;');
    SET input = REPLACE(input, '"', '&quot;');
    SET input = REPLACE(input, '''', '&#39;');
    RETURN input;
END//
DELIMITER ;

CREATE PROCEDURE `AddWebUser`(IN p_name VARCHAR(40), IN p_phone INT)
BEGIN
    -- Insert sanitized input into the table
    INSERT INTO `homepageusers` (`Name`, `Phone`) VALUES (`html_encode`(p_name), p_phone);
END;

CALL `AddWebUser`('<script>alert(''unsafe'')</script>', 123456789);
SELECT * FROM `homepageusers`;

-- Ulemper: Der skal være en SP til update også. Det virker kun på det data der kommer igennem SP


-- -----------------------------------------------------------------------------------------------------
-- Metode 4 en trigger på insert, update der encoder feltet...
-- Drop table og opret igen fra det nye udgangspunkt
-- Samme udfordring med HTML encoding som i metode 3
-- -----------------------------------------------------------------------------------------------------

DROP TRIGGER IF EXISTS homepageusersEncodeNameOnInsert;

DELIMITER //
CREATE TRIGGER `homepageusersEncodeNameOnInsert`
BEFORE INSERT ON `homepageusers`
FOR EACH ROW
BEGIN
    IF (NEW.`Name` IS NOT NULL) THEN
        SET NEW.`Name` = `html_encode`(NEW.`Name`);
    END IF;
END//
DELIMITER ;

DROP TRIGGER IF EXISTS homepageusersEncodeNameOnUpdate;

DELIMITER //
CREATE TRIGGER `homepageusersEncodeNameOnUpdate`
BEFORE UPDATE ON `homepageusers`
FOR EACH ROW
BEGIN
    IF NEW.`Name` IS NOT NULL AND (OLD.`Name` IS NULL OR OLD.`Name` <> NEW.`Name`) THEN
        SET NEW.`Name` = `html_encode`(NEW.`Name`);
    END IF;
END//
DELIMITER ;

-- TEST 
INSERT INTO `homepageusers`(`Name`, `Phone`) 
VALUES ('<script>alert("unsafe")</script>',87654321);

UPDATE `homepageusers`
SET `Phone` = 12345678
WHERE `Id` = 1;

UPDATE `homepageusers`
SET `Name` = '<script>alert("XSS")</script>'
WHERE `Id` = 1;

SELECT * FROM `homepageusers`;
