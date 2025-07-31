#!/bin/bash

CONFIG_DIR="/etc/cimmyt-ggce-tool"
TEMPLATE_DIR="/usr/share/cimmyt-ggce-tool"
LIB_DIR="/usr/lib/cimmyt-ggce-tool"

database::create_database () {
    local db_name="$1"
    local file_env="$CONFIG_DIR/config.env"
    local compose_file="$LIB_DIR/docker/compose.yml"
    if [ -z "$db_name" ]; then
        echo "❌ Error: Error no hay nombre de base de datos para crear." >&2
        return 1
    fi
    
    docker compose --env-file $file_env -f $compose_file exec ggce-mssql-client /scripts/check_and_create_db.sh "$db_name"
    echo "✅ Exito: Se creo la nueva base de datos correctamente $db_name." >&2
    return 0
}

database::create_user () {
    local db_name="$1"
    local user_name="$2"
    local user_pass="$3"
    local file_env="$CONFIG_DIR/config.env"
    local compose_file="$LIB_DIR/docker/compose.yml"
    if [ -z "$db_name" ] || [ -z "$user_name" ] || [ -z "$user_pass" ]; then
        echo "❌ Error: Los parametros para el usuario o base de datos no estan definidos." >&2
        return 1
    fi
    docker compose --env-file $file_env -f $compose_file exec ggce-mssql-client /scripts/check_and_create_user.sh "$db_name" "$user_name" "$user_pass"

    echo "✅ Exito: Se creo la nueva base de datos correctamente $db_name." >&2
    return 0
}