#!/bin/bash

# check_and_create_user.sh
# Runs inside the ggce-mssql-client container.
# Argument 1: Database name where the user will be created.
# Argument 2: Username for the new login and user.
# Argument 3: Password for the new login.

set -e # Exit immediately if a command fails.

DB_NAME="$1"
DB_USER="$2"
DB_PASSWORD="$3"

# --- Input Validation ---
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
  echo "Error: Missing arguments. Usage: $0 <db_name> <db_user> <db_password>" >&2
  exit 1
fi

if [ -z "$SA_PASSWORD" ]; then
  echo "Error: SA_PASSWORD environment variable is not set inside the container." >&2
  exit 1
fi

# Escape single quotes in the password for the SQL query
DB_PASSWORD_ESCAPED=$(echo "$DB_PASSWORD" | sed "s/'/''/g")

echo "--- Configuring user [$DB_USER] for database [$DB_NAME] ---"

# --- SQL Logic ---
SQL_COMMAND="
-- Create server-level login if it does not exist
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'$DB_USER')
BEGIN
    CREATE LOGIN [$DB_USER] WITH PASSWORD = N'$DB_PASSWORD_ESCAPED';
    PRINT 'Login [$DB_USER] created.';
END

-- Switch to the target database to create the user
USE [$DB_NAME];

-- Create database user from the login if it does not exist
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'$DB_USER')
BEGIN
    CREATE USER [$DB_USER] FOR LOGIN [$DB_USER];
    ALTER ROLE db_owner ADD MEMBER [$DB_USER];
    PRINT 'User [$DB_USER] created and granted db_owner role in database [$DB_NAME].';
END
ELSE
BEGIN
    PRINT 'User [$DB_USER] already exists in database [$DB_NAME].';
END"

/opt/mssql-tools/bin/sqlcmd -S ggce-mssql -U sa -P "$SA_PASSWORD" -Q "$SQL_COMMAND"

echo "--- Configuration for user [$DB_USER] completed. ---"