
# POC XSS Attack in MSSQL, MySQL, and PostgreSQL

This document provides an overview of the SQL scripts demonstrating Cross-Site Scripting (XSS) vulnerabilities in MSSQL, MySQL, and PostgreSQL databases. Each script is part of a database blue hat hacking theme, showcasing both the vulnerability and various methods to mitigate the risk.

## 1. MSSQL Script

**Purpose**: The MSSQL script is designed to demonstrate the presence of XSS vulnerabilities within a database. It walks through the process of creating a vulnerable table, inserting potentially harmful data, and then using various methods to mitigate these vulnerabilities.

**Key Steps**:
- Creation of a test database and table named `homepageusers`.
- Insertion of XSS payloads directly into the `Name` and `Phone` fields.
- Demonstration of potential issues when this data is rendered in a web application.
- Various methods to mitigate XSS, such as using proper data types, implementing stored procedures, and escaping user input.

**Distinctive Feature**: The script showcases SQL-based mitigations specific to MSSQL, such as using stored procedures and input validation techniques.

## 2. MySQL Script

**Purpose**: Similar to the MSSQL script, the MySQL script focuses on identifying and addressing XSS vulnerabilities. The script includes examples that are tailored to MySQL's syntax and best practices.

**Key Steps**:
- Creation of a database and a table with a similar structure (`homepageusers`).
- Demonstration of XSS attacks through malicious script injection in user inputs.
- Implementation of different mitigation strategies, including using stored procedures, functions, and triggers specific to MySQL.

**Distinctive Feature**: The MySQL script emphasizes using MySQL's unique features like `CHARACTER SET` and specific MySQL functions to prevent XSS attacks.

## 3. PostgreSQL Script

**Purpose**: The PostgreSQL script follows the same theme of XSS vulnerability identification and mitigation but utilizes PostgreSQL-specific syntax and methods.

**Key Steps**:
- Creation of a similar test setup with a table named `homepageusers`.
- Insertion of XSS payloads and evaluation of how PostgreSQL handles such inputs.
- Use of PostgreSQL's procedural language (PL/pgSQL) to create functions and triggers that sanitize user inputs.

**Distinctive Feature**: This script uses PostgreSQL's powerful procedural language and trigger-based solutions to automatically sanitize inputs before they are inserted or updated in the database.

## Differences Between MSSQL, MySQL, and PostgreSQL Approaches

- **Syntax and Functionality**: Each script is written in the respective SQL dialect, demonstrating the unique capabilities and functions available in MSSQL, MySQL, and PostgreSQL.
- **Mitigation Techniques**: While all three scripts address XSS vulnerabilities, the methods vary based on the database system's available functions and procedural capabilities.
- **Trigger and Stored Procedure Use**: Each database handles triggers and stored procedures differently, and this is reflected in the scripts. PostgreSQL, for example, leverages PL/pgSQL extensively for encoding, while MSSQL might use T-SQL-based stored procedures.
