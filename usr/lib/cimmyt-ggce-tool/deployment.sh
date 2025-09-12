#!/bin/bash

source /usr/lib/cimmyt-ggce-tool/database.sh
source /usr/lib/cimmyt-ggce-tool/ui.sh

CONFIG_DIR="/etc/cimmyt-ggce-tool"
LIB_DIR="/usr/lib/cimmyt-ggce-tool"
FILE_ENV="$CONFIG_DIR/config.env"
SOURCE_FILE_COMPOSE="$LIB_DIR/docker/compose.yml"


deployment::load_env() {
    if [ -f "$FILE_ENV" ]; then
        ui::echo-message "Cargando las variables del archivo $FILE_ENV..."
        # Use `set -a` and `source` for robustly loading and exporting variables.
        # This correctly handles spaces, quotes, and special characters in values,
        # unlike the previous `grep | xargs` method.
        set -a
        source "$FILE_ENV"
        set +a
        # Validar que las variables críticas se hayan cargado correctamente
        if [ -n "$DB_NAME" ]; then
            ui::echo-message "Variable DB_NAME cargada con éxito: '$DB_NAME'" "success"
            return 0
        else
            ui::echo-message "La variable DB_NAME no está definida o está vacía en el archivo de configuración." "error"
            ui::echo-message "Por favor, verifique su archivo '$FILE_ENV'." "error"
            return 1
        fi
    else
        ui::echo-message "El archivo $FILE_ENV no fue encontrado." "error"
        return 1
    fi
}

deployment::prepare_network_volumnes() {
    if ! environment::validate_docker; then
        return 1
    fi

    if ! environment::port_validation; then
        return 1
    fi
    docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" down
    echo "Preparando recursos de Docker"
    if ! docker network inspect ggce-network &>/dev/null; then
        ui::echo-message "Creando la red de Docker 'ggce-network'..."
        if ! docker network create ggce-network >/dev/null; then
            ui::echo-message "Falló la creación de la red de Docker 'ggce-network'." "error"
            return 1
        fi
    fi
    ui::echo-message "La red de Docker 'ggce-network' está lista." "success"

    local volumes_to_manage=("ggce-database-store" "ggce-database-log" "ggce-data-api" "ggce-traefik-data")
    ui::echo-message "Recreando los volúmenes de Docker: ${volumes_to_manage[*]}"
    for volume in "${volumes_to_manage[@]}"; do
        docker volume rm "$volume" &>/dev/null || true
        if ! docker volume create "$volume" >/dev/null; then
            ui::echo-message "Falló la creación del volumen '$volume'." "error"
            return 1
        fi
    done
    ui::echo-message "Los volúmenes de Docker están listos." "success"
}


deployment::prepare_resources() {
    if ! deployment::prepare_network_volumnes; then
        return 1
    fi

    ui::echo-message "Construyendo las imágenes de Docker..."
    docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" build ggce-mssql-client ggce-version-tracker
    ui::echo-message "Las imágenes de Docker están listas." "success"
    ui::echo-message "Preparando la base de datos y agregando la configuracion."
    if ! docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" up -d ggce-mssql >/dev/null; then
        ui::echo-message "No es posible iniciar la base de datos." "error"
        return 1
    fi
    ui::echo-message "El contenedor de base de datos fue creado." "success"
    ui::echo-message "Inicia el proceso de carga de las nuevas varaibles creadas por el usuario."
    if ! deployment::load_env &> /dev/null; then 
        return 1
    fi
    ui::echo-message "Varaibles cargadas exitosamente." "success"
    ui::echo-message "Creando base de datos en el contenedor ${DB_NAME}."
    if ! database::create_database "$DB_NAME"; then
        return 1
    fi
    ui::echo-message "Base de datos creada exitosamente." "success"
    ui::echo-message "Creando usuario de base de datos y sus permisos ${USER_DB} - ${PASSWORD_DB}."
    if ! database::create_user "$DB_NAME" "$USER_DB" "$PASSWORD_DB"; then
        return 1
    fi
    ui::echo-message "Creando el usuario de base de datos exitosamente." "success"
    ui::echo-message "Se da inicio el proxy GGCE-TRAEFIK."
    if ! docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" up -d ggce-traefik > /dev/null; then
        ui::echo-message "No fue posible iniciar el proxy GGCE-TRAEFIK." "error"
        return 1
    fi
    ui::echo-message "Inicio GGCE-TRAEFIK." "success"
    ui::echo-message "Se da inicio la aplicación GGCE-API."
    if ! docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" up -d ggce-api > /dev/null; then
        ui::echo-message "Al iniciar la aplicacion GGCE-API." "error"
        return 1
    fi
    ui::echo-message "Inicio GGCE-API." "success"
    ui::echo-message "Se da inicio la aplicación GGCE-UI."
    if ! docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" up -d ggce-ui > /dev/null; then
        ui::echo-message "No fue posible iniciar la aplicacion GGCE-UI." "error"
        return 1
    fi
    ui::echo-message "Inicio GGCE-UI." "success"

    return 0
}



deployment::start_resources() {
    if ! environment::validate_docker; then
        return 1
    fi
    if ! environment::validate_installation; then
        return 1
    fi
    ui::echo-message "Iniciando los servicios..."
    docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" up -d ggce-traefik ggce-mssql 
    docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" up -d ggce-api ggce-ui
    return 0
}

deployment::stop_resources() {
    if ! environment::validate_docker; then
        ui::echo-message "El servicio de docker no esta instalado." "error"    
        return 1
    fi
    if ! environment::validate_installation; then
        ui::echo-message "No se ha ejecutado el comando -i." "error"    
        return 1
    fi
    ui::echo-message "Deteniendo los servicios..."
    docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" down 
    return 0
}

deployment::stop_only_ggce() {
    if ! environment::validate_docker; then
        ui::echo-message "El servicio de docker no esta instalado." "error"    
        return 1
    fi
    if ! environment::validate_installation; then
        ui::echo-message "No se ha ejecutado el comando -i." "error"    
        return 1
    fi
    ui::echo-message "Deteniendo los servicios..."
    docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" down ggce-api ggce-ui
    return 0
}

deployment::start_only_ggce() {
    if ! environment::validate_docker; then
        return 1
    fi
    if ! environment::validate_installation; then
        return 1
    fi
    ui::echo-message "Iniciando los servicios..."
    docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" up -d ggce-api ggce-ui
    return 0
}

deployment::list_remote_version(){
    local file_version="$CONFIG_DIR/version-tracker/version.json"

    ui::echo-message "Buscando las nuevas versiones de GGCE."
    docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" build ggce-version-tracker
    docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" up -d ggce-version-tracker
    sleep 10
    ui::echo-message "Validando la descarga."
    if [ ! -f "$file_version" ]; then
        ui::echo-message "Contenido de $(dirname "$file_version"):" "warning"
        ls -la "$(dirname "$file_version")"
        ui::echo-message "No se genero el archivo '$file_version' con la informacion de las versiones." "error"
        return 1
    else
        docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" down ggce-version-tracker
    fi
    return 0
    
}

deployment::db(){
    ui::echo-message "Preparando la base de datos y agregando la configuracion."
    if ! docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" up -d ggce-mssql >/dev/null; then
        ui::echo-message "No es posible iniciar la base de datos." "error"
        return 1
    fi

    ui::echo-message "Inicia el proceso de carga de las nuevas varaibles creadas por el usuario."
    if ! deployment::load_env &> /dev/null; then 
        return 1
    fi
    ui::echo-message "Varaibles cargadas exitosamente." "success"
    ui::echo-message "Creando base de datos en el contenedor ${DB_NAME}."
    if ! database::create_database "$DB_NAME"; then
        return 1
    fi
    ui::echo-message "Base de datos creada exitosamente." "success"
    ui::echo-message "Creando usuario de base de datos y sus permisos ${USER_DB} - ${PASSWORD_DB}."
    if ! database::create_user "$DB_NAME" "$USER_DB" "$PASSWORD_DB"; then
        return 1
    fi
    return 0
}

deployment::certificados() {
    local cert_dir="$CONFIG_DIR/cert"
    local cert_file="$cert_dir/cert.crt"
    local key_file="$cert_dir/key.key"

    ui::echo-message "Gestionando certificados SSL para la instalación..."

    # Asegurarse de que el directorio de certificados exista
    if ! mkdir -p "$cert_dir"; then
        ui::echo-message "No se pudo crear el directorio para certificados en '$cert_dir'. Verifique los permisos." "error"
        return 1
    fi

    # Eliminar certificados existentes para forzar la regeneración durante la instalación
    if [ -f "$cert_file" ] || [ -f "$key_file" ]; then
        ui::echo-message "Eliminando certificados SSL existentes para generar unos nuevos..." "warning"
        if ! rm -f "$cert_file" "$key_file"; then
            ui::echo-message "No se pudieron eliminar los certificados existentes. Verifique los permisos en '$cert_dir'." "error"
            return 1
        fi
    fi

    ui::echo-message "Generando nuevos certificados SSL autofirmados..."
    # Usar 'run --rm' para ejecutar el contenedor de un solo uso y limpiarlo automáticamente.
    # Se captura la salida para poder mostrarla en caso de que ocurra un error.
    local output
    output=$(docker compose --env-file "$FILE_ENV" -f "$SOURCE_FILE_COMPOSE" run --rm ggce-cert-generator 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        ui::echo-message "Falló la generación de certificados. Revise el resultado del contenedor anterior." "error"
        ui::echo-message "Salida del comando de Docker:" "error"
        echo "$output" >&2
        return 1
    fi

    # Verificar que los certificados se crearon correctamente
    if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
        ui::echo-message "Los certificados SSL no fueron encontrados después de la ejecución." "error"
        return 1
    fi

    return 0
}