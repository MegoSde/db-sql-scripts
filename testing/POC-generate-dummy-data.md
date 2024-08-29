# POC for Generering af Dummy Data i MSSQL

## Formål
Formålet med dette proof of concept (POC) er at demonstrere, hvordan man kan generere dummy data til testning i en MSSQL-database. Dette kan være nyttigt i udviklings- og testmiljøer, hvor der er behov for realistiske datasæt til at validere funktionaliteten af databaser og applikationer.

## Tabeller og Relationen
I denne POC oprettes to tabeller: `orders` og `orderline`. Tabellen `orders` repræsenterer en ordre, mens `orderline` repræsenterer individuelle linjer inden for en ordre. En ordre kan indeholde flere linjer.
```mermaid
erDiagram
    ORDERS {
        int Id PK
        datetime start_ts
        datetime end_ts
        int seats
    }
    
    ORDERLINE {
        int Id PK
        int OrderID FK
        int paid
    }
    
    ORDERS ||--o{ ORDERLINE : contains
```

## Proces Flowchart for Generering af Dummy Data

Nedenfor er en flowchart, der beskriver processen for generering af dummy data til `orders` og `orderline` tabellerne:

```mermaid
flowchart TD
    A[Generate dummy data] --> B[Start generering af dummy data for 'orders']
    B --> B1[insert order med random start-tidspunkt]
    B1 --> B2[update order med slut-tidspunkt der 2 timer efter start-tidspunkt]
    B2 --> C[Generate dummy data for orderline]
    C --> C1[Open en cursor fra alle orders]
    C1 --> C2{Fetch next}
    C2 -->|True|C3[opdater order med et tilfældig antal seats]
    C3 --> C4[For antallet af seats indsæt en orderline]
    C4 --> C2
    C2 -->|False|C5[Close cursor]
    C5 --> D[Færdig]
```

## Anvendelse
Ved at køre dette script, oprettes de nødvendige tabeller og der genereres dummy data. Denne data kan bruges til at teste forespørgsler, datavalidering, performance, og andre aspekter af databaseoperationer i en sikker testmiljø.

