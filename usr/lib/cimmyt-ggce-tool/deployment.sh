#!/bin/bash

source /usr/lib/cimmyt-ggce-tool/database.sh

CONFIG_DIR="/etc/cimmyt-ggce-tool"
TEMPLATE_DIR="/usr/share/cimmyt-ggce-tool"
LIB_DIR="/usr/lib/cimmyt-ggce-tool"



deployment::load_env() {
    local file_env="$CONFIG_DIR/config.env"
    if [ -f $file_env ]; then
        echo "=> Cargando las varaibles del archivo $file_env..."
        export $(grep -v '^#' $file_env | xargs)
    else
        echo "❌ Error: El archivo $file_env no fue encontrado." >&2
        return 1
    fi
    return 0
}

deployment::_validate_docker(){
    if ! command -v docker &> /dev/null; then
        echo "❌ Error: Docker no está instalado o no está en el PATH."
        exit 1
    fi
    if ! docker compose version &> /dev/null; then
        echo "❌ Error: Docker Compose (plugin) no está instalado"
        exit 1
    fi
    return 0
}

deployment::prepare_resources() {
    local file_env="$CONFIG_DIR/config.env"
    local source_file_compose="$LIB_DIR/docker/compose.yml"
    if !deployment::_validate_docker; then
        return 1
    fi
    echo => "Preparando recursos de Docker"
    if ! docker network inspect ggce-network &>/dev/null; then
        echo "=> Creando la red de Docker 'ggce-network'..."
        if ! docker network create ggce-network >/dev/null; then
            echo "❌ Error: Falló la creación de la red de Docker 'ggce-network'." >&2
            return 1
        fi
    fi
    echo "✅ Exito: La red de Docker 'ggce-network' está lista."

    local volumes_to_manage=("ggce-database-store" "ggce-database-log" "ggce-data-api")
    echo "=> Recreando los volúmenes de Docker: ${volumes_to_manage[*]}"
    for volume in "${volumes_to_manage[@]}"; do
        docker volume rm "$volume" &>/dev/null || true
        if ! docker volume create "$volume" >/dev/null; then
            echo "❌ Error: Falló la creación del volumen '$volume'." >&2
            return 1
        fi
    done
    echo "✅ Exito: Los volúmenes de Docker están listos."
    echo "=> Construyendo las imágenes de Docker..."

    docker compose --env-file $file_env -f $source_file_compose build ggce-mssql-client ggce-version-tracker

    echo "✅ Exito: Las imágenes de Docker están listas."
    echo "=> Preparando la base de datos y agregando la configuracion."
    if ! docker compose --env-file $file_env -f $source_file_compose up -d ggce-mssql >/dev/null; then
        echo "❌ Error: al iniciar la base de datos." >&2
        return 1
    fi
    echo "✅ Exito: El contenedor de base de datos fue creado."
    echo "=> Inicia el proceso de carga de las nuevas varaibles creadas por el usuario."
    if !deployment::load_env &> /dev/null; then 
        return 1
    fi
    echo "✅ Exito: Varaibles cargadas exitosamente."
    echo "=> Creando base de datos en el contenedor."
    if !database::create_database "$DB_NAME" &> /dev/null; then
        return 1
    fi
    echo "✅ Exito: Base de datos creada exitosamente."
    echo "=> Creando usuario de base de datos y sus permisos."
    if !database::create_user "$DB_NAME" "$USER_DB" "$PASSWORD_DB" &> /dev/null; then
        return 1
    fi
    echo "✅ Exito: Creando el usuario de base de datos exitosamente."
    echo "=> Se inicio la aplicación GGCE-API."
    if ! docker compose --env-file $file_env -f "$source_file_compose" up -d ggce-mail-server ggce-api > /dev/null; then
        echo "❌ Error: Al iniciar la aplicacion GGCE-API." >&2
        return 1
    fi
    echo "=> Se inicio la aplicación GGCE-UI."
    if ! docker compose --env-file $file_env -f "$source_file_compose" up -d ggce-ui > /dev/null; then
        echo "❌ Error: Al iniciar la aplicacion GGCE-UI."
        return 1
    fi

    return 0
}

deployment::start_resources() {
    if deployment::_validate_docker then
        return 1
    fi

    docker compose --env-file $file_env -f "$source_file_compose" up -d ggce-mssql ggce-mail-server ggce-api ggce-ui
    return 0
}

deployment::stop_resources() {
    if deployment::_validate_docker then
        return 1
    fi

    docker compose --env-file $file_env -f "$source_file_compose" down
    return 0
}