#!/bin/bash
# backup_db.sh
# Runs inside the ggce-mssql-client container.
# Argument 1: Name of the database to back up.

set -e

DB_NAME="$1"

if [ -z "$DB_NAME" ]; then
  echo "Error: No database name provided." >&2
  exit 1
fi

if [ -z "$SA_PASSWORD" ]; then
  echo "Error: SA_PASSWORD environment variable is not set." >&2
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE_NAME="${DB_NAME}_${TIMESTAMP}.bak"
BACKUP_PATH="/var/opt/mssql/dump/${BACKUP_FILE_NAME}"

echo "--- Starting backup for database [$DB_NAME] ---"
echo "Backup file will be created at: ${BACKUP_PATH}"

SQL_COMMAND="BACKUP DATABASE [$DB_NAME] TO DISK = N'$BACKUP_PATH' WITH FORMAT, INIT, COMPRESSION, STATS = 10"

/opt/mssql-tools/bin/sqlcmd -S ggce-mssql -U sa -P "$SA_PASSWORD" -Q "$SQL_COMMAND"

if [ -f "$BACKUP_PATH" ]; then
  echo "--- Backup for [$DB_NAME] completed successfully. ---"
  echo "Backup file: ${BACKUP_FILE_NAME}"
  echo "Full path: ${BACKUP_PATH}"
else
  echo "--- ERROR: Backup for [$DB_NAME] failed. ---" >&2
  echo "The backup file '${BACKUP_FILE_NAME}' was not found at '${BACKUP_PATH}' after the command executed." >&2
  echo "Please check SQL Server logs for more details, or verify directory permissions." >&2
  exit 1 # Exit with an error code
fi