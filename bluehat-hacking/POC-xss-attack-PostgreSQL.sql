-- Formål: Demonstrere sårbarheden for XSS-attack i en MSSQL-database
-- Tip: Sørg for at afvikle kommandoerne en ad gangen for at forstå konsekvenserne.

-- -----------------------------------------------------------------------------------------------------
-- Afsnit: Oprettelse af testdatabase
-- Vi starter med at oprette en ny testdatabase for at sikre, at ingen eksisterende data kompromitteres.
-- -----------------------------------------------------------------------------------------------------
CREATE DATABASE "POC_XSS_TestDB";
-- forbind til den nye database POC_XSS_TestDB

-- -----------------------------------------------------------------------------------------------------
-- Udgangspunkt: Oprettelse af en tabel med en potentiel XSS-sårbarhed
-- Tabellen "UserComments" oprettes med en kolonne til kommentarer, hvor XSS-angreb kan udføres.
-- Vigtigt: Dette alle metoder tager udgangspunkt i dette udgangspunkt!
-- -----------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS "homepageusers";
CREATE TABLE "homepageusers" (
    "Id" SERIAL PRIMARY KEY,
    "Name" VARCHAR(100) NOT NULL,
    "Phone" VARCHAR(100) NOT NULL
);

-- -----------------------------------------------------------------------------------------------------
-- Problemstilling: Demonstration af problemmet
-- -----------------------------------------------------------------------------------------------------

INSERT INTO "homepageusers"("Name", "Phone") 
VALUES ('<script>alert("unsafe & safe Utf8CharsDon''tGetEncoded ÄöÜ - Conex")</script>',
		'<script>alert(87654321)</script>');
-- Dette vil potentielt returnere et java script direkte til browseren, hvor det vil blive afviklet
SELECT * FROM "homepageusers";

-- -----------------------------------------------------------------------------------------------------
-- Metode 1 Brug de rigtig datatyper og gør dem så små som mulige.
-- Tip: Denne metode bør altid være en del af løsningen
-- Husk: at dette typisk kræver specificering i krav specifikationen
-- -----------------------------------------------------------------------------------------------------
-- Dette bliver det nye udgangspunkt...

DROP TABLE IF EXISTS "homepageusers";
CREATE TABLE "homepageusers" (
    "Id" SERIAL PRIMARY KEY,
    "Name" VARCHAR(50) NOT NULL,
    "Phone" INT NOT NULL
);

INSERT INTO "homepageusers"("Name", "Phone") 
VALUES 
    ('<script>alert("unsafe")</script>', 87654321),
    ('Navn Navnesen', 87654321);
   
-- Det er stadig muligt med XSS, men mulighederne er blevet mindre, forsøg også med tidligere inserts
SELECT * FROM "homepageusers";

-- -----------------------------------------------------------------------------------------------------
-- Metode 2 Tillad kun de tegn der skal bruges
-- drop table og opret igen fra det nye udgangspunkt
-- -----------------------------------------------------------------------------------------------------

ALTER TABLE "homepageusers"
ADD CONSTRAINT "stdName" CHECK ("Name" !~ '[^ A-Za-z]');

-- Første insert vil fejl da den indeholder andre chars end A-Za-z
INSERT INTO "homepageusers"("Name", "Phone") 
VALUES ('<script>alert("unsafe")</script>',87654321);
-- anden insert vil stadig virke.
INSERT INTO "homepageusers"("Name", "Phone") 
VALUES ('Navn navnesen',87654321);

SELECT * FROM "homepageusers";

-- Fjern constraint. Nødvendig for de følgende metoder
ALTER TABLE "homepageusers"
DROP CONSTRAINT "stdName";

-- ulempe special tegn er ikke tilladt

-- -----------------------------------------------------------------------------------------------------
-- Metode 3 Hvis det skal være muligt at indsætte special tegn. Overvej at html encode feltet via en stored procedure
-- drop table og opret igen fra det nye udgangspunkt
-- -----------------------------------------------------------------------------------------------------

-- Der er behov for en custom function til at lave html encoding
CREATE OR REPLACE FUNCTION "html_encode"(input TEXT) 
RETURNS TEXT AS $$
BEGIN
    RETURN replace(
               replace(
                   replace(
                       replace(
                           replace(input, '&', '&amp;'), -- Replace & first
                       '<', '&lt;'),  -- Replace <
                   '>', '&gt;'),  -- Replace >
               '''', '&#39;'),  -- Replace '
           '"', '&quot;'); -- Replace "
END;
$$ LANGUAGE plpgsql;

-- SP for insert 
CREATE OR REPLACE FUNCTION "AddWebUser"(p_name VARCHAR(40), p_phone INT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO "homepageusers" ("Name", "Phone") VALUES ("html_encode"(p_name), p_phone);
END;
$$ LANGUAGE plpgsql;

-- TEST
SELECT "AddWebUser"('<script>alt(''unsafe'')</script>', 123456789);
SELECT * FROM "homepageusers";

-- Ulemper: der skal være en SP til update også. Det virker kun på det data der kommer igennem SP


-- -----------------------------------------------------------------------------------------------------
-- Metode 4 en trigger på insert, update der encoder feltet...
-- drop table og opret igen fra det nye udgangspunkt
-- Samme udfordring med html encoding som i metode 3
-- -----------------------------------------------------------------------------------------------------
ALTER TABLE "homepageusers"
ALTER COLUMN "Name" TYPE VARCHAR(70);

CREATE OR REPLACE FUNCTION "encode_homepageusers_name"()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW."Name" IS DISTINCT FROM OLD."Name") THEN
        NEW."Name" := "html_encode"(NEW."Name");
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER "homepageusers_encode_name"
BEFORE INSERT OR UPDATE ON "homepageusers"
FOR EACH ROW
EXECUTE FUNCTION "encode_homepageusers_name"();


-- TEST 
INSERT INTO "homepageusers"("Name", "Phone") 
VALUES ('<script>alert("unsafe")</script>',87654321);

UPDATE "homepageusers"
SET "Phone" = 12345678
WHERE "Id" = 4;

UPDATE "homepageusers"
SET "Name" = '<script>alert("XSS")</script>', "Phone" = 123456789
WHERE "Id" = 1;

SELECT * FROM "homepageusers";
