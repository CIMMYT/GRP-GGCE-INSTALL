#!/bin/bash

source /usr/lib/cimmyt-ggce-tool/ui.sh

CONFIG_DIR="/etc/cimmyt-ggce-tool"
LIB_DIR="/usr/lib/cimmyt-ggce-tool"

database::create_database () {
    local db_name="$1"
    local file_env="$CONFIG_DIR/config.env"
    local compose_file="$LIB_DIR/docker/compose.yml"
    if [ -z "$db_name" ]; then
        ui::echo-message "El nombre de la base de datos no puede ser nulo o vacío." "error"
        return 1
    fi
    
    # Execute the command and check its exit status.
    # Docker compose will print any errors from the container script to stderr.
    docker compose --env-file "$file_env" -f "$compose_file" up -d ggce-mssql-client
    sleep 10
    output=$(docker compose --env-file "$file_env" -f "$compose_file" exec ggce-mssql-client /scripts/check_and_create_db.sh "$db_name" 2>$1)
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        ui::echo-message "Falló la ejecución del script para crear la base de datos '$db_name'." "error"
        ui::echo-message "$output"
        ui::echo-message "$exit_code"
        return 1
    fi
    docker compose --env-file "$file_env" -f "$compose_file" down ggce-mssql-client
    ui::echo-message "Se creó la nueva base de datos correctamente: '$db_name'." "success"
    return 0
}

database::create_user () {
    local db_name="$1"
    local user_name="$2"
    local user_pass="$3"
    local file_env="$CONFIG_DIR/config.env"
    local compose_file="$LIB_DIR/docker/compose.yml"
    if [ -z "$db_name" ]; then
        ui::echo-message "El nombre de la base de datos no puede ser nulo o vacío." "error"
        return 1
    fi
    if [ -z "$user_name" ]; then
        ui::echo-message "El nombre de usuario no puede ser nulo o vacío." "error"
        return 1
    fi
    if [ -z "$user_pass" ]; then
        ui::echo-message "La contraseña del usuario no puede ser nula o vacía." "error"
        return 1
    fi

    docker compose --env-file "$file_env" -f "$compose_file" up -d ggce-mssql-client
    sleep 10
    output=$(docker compose --env-file "$file_env" -f "$compose_file" exec ggce-mssql-client /scripts/check_and_create_user.sh "$db_name" "$user_name" "$user_pass" 2>$1)
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        ui::echo-message "Falló la ejecución del script para crear el usuario '$user_name'." "error"
        return 1
    fi
    docker compose --env-file "$file_env" -f "$compose_file" down ggce-mssql-client
    ui::echo-message "Se creó el usuario '$user_name' correctamente." "success"
    return 0
}