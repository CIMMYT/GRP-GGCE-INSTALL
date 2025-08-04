#!/bin/bash

source /usr/lib/cimmyt-ggce-tool/ui.sh

CONFIG_DIR="/etc/cimmyt-ggce-tool"
LIB_DIR="/usr/lib/cimmyt-ggce-tool"

database::create_database () {
    local db_name="$1"
    local file_env="$CONFIG_DIR/config.env"
    local compose_file="$LIB_DIR/docker/compose.yml"
    if [ -z "$db_name" ]; then
        ui::echo-message "Error no hay nombre de base de datos para crear." "error"
        return 1
    fi
    
    docker compose --env-file $file_env -f $compose_file exec ggce-mssql-client /scripts/check_and_create_db.sh "$db_name"
    ui::echo-message "Se creo la nueva base de datos correctamente $db_name." "success"
    return 0
}

database::create_user () {
    local db_name="$1"
    local user_name="$2"
    local user_pass="$3"
    local file_env="$CONFIG_DIR/config.env"
    local compose_file="$LIB_DIR/docker/compose.yml"
    if [ -z "$db_name" ] || [ -z "$user_name" ] || [ -z "$user_pass" ]; then
        ui::echo-message "Los parametros para el usuario o base de datos no estan definidos." "error"
        return 1
    fi
    docker compose --env-file $file_env -f $compose_file exec ggce-mssql-client /scripts/check_and_create_user.sh "$db_name" "$user_name" "$user_pass"
    ui::echo-message "Se creo el usuario $user_name  correctamente" "success"
    return 0
}