#!/bin/bash

# check_and_create_db.sh
# Runs inside the mssql-client-init container.
# Argument 1: Name of the database to check/create.

set -e # Exit immediately if a command fails.

DB_NAME="$1"

# --- Input Validation ---
if [ -z "$DB_NAME" ]; then
  echo "Error: No database name provided as an argument." >&2
  exit 1
fi

if [ -z "$SA_PASSWORD" ]; then
  echo "Error: SA_PASSWORD environment variable is not set inside the container." >&2
  exit 1
fi

echo "--- Checking database: $DB_NAME ---"

# --- SQL Logic ---
SQL_COMMAND="
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'$DB_NAME')
BEGIN
    PRINT 'Database [$DB_NAME] not found. Creating...';
    CREATE DATABASE [$DB_NAME];
END
ELSE
BEGIN
    PRINT 'Database [$DB_NAME] already exists.';
END"

/opt/mssql-tools/bin/sqlcmd -S ggce-mssql -U sa -P "$SA_PASSWORD" -Q "$SQL_COMMAND"

echo "--- Check for [$DB_NAME] completed. ---"

exit 0