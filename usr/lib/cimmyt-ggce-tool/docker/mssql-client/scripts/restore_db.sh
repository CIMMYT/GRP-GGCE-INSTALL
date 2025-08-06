#!/bin/bash
# restore_db.sh
# Runs inside the ggce-mssql-client container.
# Argument 1: Name of the database to restore.
# Argument 2: Filename of the backup (.bak) located in the dump folder.

set -e

DB_NAME="$1"
BACKUP_FILE_NAME="$2"

if [ -z "$DB_NAME" ] || [ -z "$BACKUP_FILE_NAME" ]; then
  echo "Error: Missing arguments. Usage: $0 <db_name> <backup_file_name>" >&2
  exit 1
fi

if [ -z "$SA_PASSWORD" ]; then
  echo "Error: SA_PASSWORD environment variable is not set." >&2
  exit 1
fi

BACKUP_PATH="/var/opt/mssql/dump/${BACKUP_FILE_NAME}"

echo "--- Starting restore for database [$DB_NAME] from file [$BACKUP_FILE_NAME] ---"

# This command needs to be run against the 'master' database to take the target DB offline.
SQL_COMMAND="
USE master;
ALTER DATABASE [$DB_NAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [$DB_NAME] FROM DISK = N'$BACKUP_PATH' WITH FILE = 1, REPLACE, STATS = 5;
ALTER DATABASE [$DB_NAME] SET MULTI_USER;
"

echo "Executing restore command..."
/opt/mssql-tools/bin/sqlcmd -S ggce-mssql -U sa -P "$SA_PASSWORD" -Q "$SQL_COMMAND"

echo "--- Restore for [$DB_NAME] completed successfully. ---"

exit 0