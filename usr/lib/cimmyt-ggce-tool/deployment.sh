#!/bin/bash

source /usr/lib/cimmyt-ggce-tool/database.sh

CONFIG_DIR="/etc/cimmyt-ggce-tool"
LIB_DIR="/usr/lib/cimmyt-ggce-tool"



deployment::load_env() {
    local file_env="$CONFIG_DIR/config.env"
    if [ -f $file_env ]; then
        ui::echo-message "Cargando las varaibles del archivo $file_env..."
        export $(grep -v '^#' $file_env | xargs)
    else
        ui::echo-message "El archivo $file_env no fue encontrado." "error"
        return 1
    fi
    return 0
}

deployment::_validate_docker(){
    if ! command -v docker &> /dev/null; then
        ui::echo-message "Docker no está instalado o no está en el PATH." "error"
        exit 1
    fi
    if ! docker compose version &> /dev/null; then
        ui::echo-message "Docker Compose (plugin) no está instalado" "error"
        exit 1
    fi
    return 0
}

deployment::prepare_resources() {
    local file_env="$CONFIG_DIR/config.env"
    local source_file_compose="$LIB_DIR/docker/compose.yml"
    if ! deployment::_validate_docker; then
        return 1
    fi
    docker compose --env-file $file_env -f $source_file_compose down
    echo "Preparando recursos de Docker"
    if ! docker network inspect ggce-network &>/dev/null; then
        ui::echo-message "Creando la red de Docker 'ggce-network'..."
        if ! docker network create ggce-network >/dev/null; then
            ui::echo-message "Falló la creación de la red de Docker 'ggce-network'." "error"
            return 1
        fi
    fi
    ui::echo-message "La red de Docker 'ggce-network' está lista." "success"

    local volumes_to_manage=("ggce-database-store" "ggce-database-log" "ggce-data-api")
    ui::echo-message "Recreando los volúmenes de Docker: ${volumes_to_manage[*]}"
    for volume in "${volumes_to_manage[@]}"; do
        docker volume rm "$volume" &>/dev/null || true
        if ! docker volume create "$volume" >/dev/null; then
            ui::echo-message "Falló la creación del volumen '$volume'." "error"
            return 1
        fi
    done
    ui::echo-message "Los volúmenes de Docker están listos." "success"
    ui::echo-message "Construyendo las imágenes de Docker..."
    docker compose --env-file $file_env -f $source_file_compose build ggce-mssql-client ggce-version-tracker
    ui::echo-message "Las imágenes de Docker están listas." "success"
    ui::echo-message "Preparando la base de datos y agregando la configuracion."
    if ! docker compose --env-file $file_env -f $source_file_compose up -d ggce-mssql >/dev/null; then
        ui::echo-message "No es posible iniciar la base de datos." "error"
        return 1
    fi
    ui::echo-message "El contenedor de base de datos fue creado." "success"
    ui::echo-message "Inicia el proceso de carga de las nuevas varaibles creadas por el usuario."
    if !deployment::load_env &> /dev/null; then 
        return 1
    fi
    ui::echo-message "Varaibles cargadas exitosamente." "success"
    ui::echo-message "Creando base de datos en el contenedor."
    if !database::create_database "$DB_NAME" &> /dev/null; then
        return 1
    fi
    ui::echo-message "Base de datos creada exitosamente." "success"
    ui::echo-message "Creando usuario de base de datos y sus permisos."
    if !database::create_user "$DB_NAME" "$USER_DB" "$PASSWORD_DB" &> /dev/null; then
        return 1
    fi
    ui::echo-message "Creando el usuario de base de datos exitosamente." "success"
    ui::echo-message "Se inicio la aplicación GGCE-API."
    if ! docker compose --env-file $file_env -f "$source_file_compose" up -d ggce-api > /dev/null; then
        ui::echo-message "Al iniciar la aplicacion GGCE-API." "error"
        return 1
    fi
    ui::echo-message "Se inicio la aplicación GGCE-UI."
    if ! docker compose --env-file $file_env -f "$source_file_compose" up -d ggce-ui > /dev/null; then
        ui::echo-message "No fue posible iniciar la aplicacion GGCE-UI." "error"
        return 1
    fi

    return 0
}

deployment::start_resources() {
    local file_env="$CONFIG_DIR/config.env"
    local source_file_compose="$LIB_DIR/docker/compose.yml"
    if ! deployment::_validate_docker; then
        return 1
    fi

    ui::echo-message "Iniciando los servicios..."
    docker compose --env-file "$file_env" -f "$source_file_compose" up -d ggce-mssql ggce-mail-server ggce-api ggce-ui
    return 0
}

deployment::stop_resources() {
    local file_env="$CONFIG_DIR/config.env"
    local source_file_compose="$LIB_DIR/docker/compose.yml"
    if ! deployment::_validate_docker; then
        return 1
    fi

    ui::echo-message "Deteniendo los servicios..."
    docker compose --env-file "$file_env" -f "$source_file_compose" down
    return 0
}