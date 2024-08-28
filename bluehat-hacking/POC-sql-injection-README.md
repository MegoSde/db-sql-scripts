# POC SQL Injection in MSSQL

This document explains the proof of concept (POC) for demonstrating SQL injection vulnerabilities in a Microsoft SQL Server (MSSQL) database. The POC is implemented in the accompanying SQL script.

## Overview

The POC demonstrates how SQL injection can occur in a database application when user inputs are not properly sanitized. It also shows how to prevent such vulnerabilities using best practices, such as parameterized queries and using stored procedures.

## Key Steps and Demonstrations

### 1. Initial Setup
- **Tables Created**: 
  - `[users]` table to store usernames and hashed passwords.
  - `[secrets]` table to store confidential information.
- **User Created**: 
  - `[webtester]` user, simulating an external application or API user interacting with the database.

### 2. Demonstration of Secure Login Procedure
- **Procedure**: `[ValidateLogin]`
- **Description**: This stored procedure demonstrates a secure login mechanism using parameterized queries. It prevents SQL injection by hashing the password input and comparing it securely against stored hash values.

### 3. Demonstration of SQL Injection Vulnerability
- **Procedure**: `[ValidateLoginInsecure]`
- **Description**: This stored procedure intentionally introduces SQL injection vulnerabilities by constructing SQL queries dynamically based on user input without proper sanitization. It shows how an attacker could manipulate the input to execute arbitrary SQL commands.

### 4. Defense Against SQL Injection
- **Best Practices Highlighted**:
  - Use of parameterized queries in stored procedures to prevent injection attacks.
  - Separation of privileges, where different users have different levels of access, to limit the potential damage of a successful injection.
  - Use of the `WITH EXECUTE AS OWNER` clause to ensure that stored procedures run with the necessary privileges without exposing sensitive data to all users.

## Conclusion

The POC demonstrates both the risk of SQL injection in a database environment and the strategies for mitigating such risks. By following best practices like those shown in the POC, developers can protect their applications from SQL injection attacks and secure their databases effectively.
