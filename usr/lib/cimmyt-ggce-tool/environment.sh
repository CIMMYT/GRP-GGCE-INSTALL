#!/bin/bash

source /usr/lib/cimmyt-ggce-tool/database.sh
source /usr/lib/cimmyt-ggce-tool/ui.sh

CONFIG_DIR="/etc/cimmyt-ggce-tool"
TEMPLATE_DIR="/usr/share/cimmyt-ggce-tool"

environment::_validate_password_complexity() {
    local password="$1"
    local var_name="$2"
    local score=0

    if [ ${#password} -lt 8 ]; then
        ui::echo-message "La contraseña para '$var_name' es muy corta. Debe tener al menos 8 caracteres." "warning"
        return 1
    fi

    if [[ "$password" =~ [A-Z] ]]; then ((score++)); fi
    if [[ "$password" =~ [a-z] ]]; then ((score++)); fi
    if [[ "$password" =~ [0-9] ]]; then ((score++)); fi
    if [[ "$password" =~ [^A-Za-z0-9] ]]; then ((score++)); fi

    if [ "$score" -lt 3 ]; then
        ui::echo-message "La contraseña para '$var_name' no es suficientemente compleja. Debe contener caracteres de al menos tres de los siguientes cuatro conjuntos: letras mayúsculas, letras minúsculas, números y símbolos." "warning"
        return 1
    fi

    return 0
}

environment::_validate_memory_format() {
    local memory_value="$1"
    local var_name="$2"

    if [[ ! "$memory_value" =~ ^[0-9]+[mgMG]$ ]]; then
        ui::echo-message "Formato inválido para '$var_name'. El valor debe ser un número seguido de 'm' para megabytes o 'g' para gigabytes (ej. 512m, 2g)." "warning"
        return 1
    fi

    return 0
}

environment::prepare_env_file() {
    local example_file="$TEMPLATE_DIR/env.example"
    local output_file="$CONFIG_DIR/config.env"

    if [[ ! -f "$example_file" ]]; then
        ui::echo-message "El $example_file no fue encontrado. No se puede crear el archivo .env." "error"
        return 1
    fi

    ui::echo-message "Creando archivo .env desde $example_file ---"
    local temp_file="$(mktemp)"
    > "$temp_file"

    echo
    ui::echo-message "A continuación se le solicitará que configure las variables de entorno."
    ui::echo-message "Presione ENTER para aceptar el valor por defecto que se muestra entre corchetes []."
    echo

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$temp_file"
            continue
        fi
        local var_name=$(echo "$line" | cut -d '=' -f 1)
        local default_value=$(echo "$line" | cut -d '=' -f 2-)
        if [[ "$var_name" == "GG_CE_API_VERSION" || "$var_name" == "GG_CE_UI_VERSION" ]]; then
            echo "$var_name=$default_value" >> "$temp_file"
            continue
        fi
        local user_input final_value
        if [[ "$var_name" == *PASSWORD* ]]; then
            while true; do
                read -s -p "Ingrese un valor seguro para '$var_name' [predeterminado: $default_value]: " user_input < /dev/tty
                echo ""
                final_value="${user_input:-$default_value}"
                if environment::_validate_password_complexity "$final_value" "$var_name"; then
                    break
                fi
            done
        elif [[ "$var_name" == *MEMORY* ]]; then
            while true; do
                read -p "Ingrese el valor para '$var_name' [predeterminado: $default_value]: " user_input < /dev/tty
                final_value="${user_input:-$default_value}"
                if environment::_validate_memory_format "$final_value" "$var_name"; then
                    break
                fi
            done
        else
            read -p "Ingrese el valor para '$var_name' [predeterminado: $default_value]: " user_input < /dev/tty
            final_value="${user_input:-$default_value}"
        fi

        echo "$var_name=$final_value" >> "$temp_file"
    done < "$example_file"
    mv "$temp_file" "$output_file"
    echo ""
    ui::echo-message "Archivo creado: $output_file" "success"
    return 0
}

environment::port_validation (){
    local ports=(3001 3002 1400)
    local all_ports_free=true
    for port in "${ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            ui::echo-message "Puerto $port está en uso." "error"
            all_ports_free=false
        else
            ui::echo-message "Puerto $port está disponible."
        fi
    done

    if [ "$all_ports_free" = false ]; then
        ui::echo-message " Uno o más puertos están ocupados. Abortando..." "error"
        return 1
    fi

    ui::echo-message "Todos los puertos requeridos están disponibles." "success"
    return 0
}

environment::validate_installation() {
    local file_env="$CONFIG_DIR/config.env"

    if [ ! -f "$file_env" ]; then
        ui::echo-message "El archivo $file_env no fue encontrado." "error"
        ui::echo-message "Confirme que ggce fue instalado con el comando -i."
        return 1
    fi
    return 0
}

environment::validate_docker(){
    if ! command -v docker &> /dev/null; then
        ui::echo-message "Docker no está instalado o no está en el PATH." "error"
        return 1
    fi
    if ! docker compose version &> /dev/null; then
        ui::echo-message "Docker Compose (plugin) no está instalado" "error"
        return 1
    fi
    return 0
}

environment::select_version(){
    local file_version="$CONFIG_DIR/version-tracker/version.json"
    local file_env="$CONFIG_DIR/config.env"

     if ! command -v jq &> /dev/null; then
        ui::echo-message "'jq' no esta instalado y es necesario para esta caracteristica" "error"
        ui::echo-message "Por favor instale 'jq' (e.g., 'sudo apt-get install jq')."
        return 1
    fi
    ui::echo-message "Seleccione la version que desea utilizar."
    (
        set -e
        local project_count
        project_count=$(jq '.projects | length' "$file_version")

        for i in $(seq 0 $((project_count - 1))); do
            local project_name
            local env_var
            project_name=$(jq -r ".projects[$i].name" "$file_version")
            env_var=$(jq -r ".projects[$i].env" "$file_version")
            ui::echo-message "Seleccione la version para: $project_name (Actualizar la variable $env_var in el archivo de configuracion)"
            mapfile -t versions_array < <(jq -r ".projects[$i].versions[]" "$file_version")
            # Forzar a 'select' a mostrar las opciones en líneas nuevas
            local OLD_COLUMNS=$COLUMNS
            COLUMNS=1
            select version in "${versions_array[@]}"; do
                if [[ -n "$version" ]]; then
                    ui::echo-message "Seleccionó la versión '$version' para $project_name."
                    if grep -q "^${env_var}=" "$file_env"; then
                        sed "s|^${env_var}=.*|${env_var}=${version}|" "$file_env" > "$file_env.tmp" && mv "$file_env.tmp" "$file_env"
                        ui::echo-message "Se actualizó la variable $env_var en el archivo de configuración." "success"
                    else
                        echo "${env_var}=${version}" >> "$file_env"
                        ui::echo-message "Se agregó la variable $env_var al archivo de configuración." "success"
                    fi
                    break
                else
                    ui::echo-message "La opción no es válida. Intente nuevamente." "warning"
                fi
            done
            COLUMNS=$OLD_COLUMNS # Restaurar el valor original de COLUMNS
        done
    )
    if [ $? -ne 0 ]; then
        ui::echo-message "No fue posible actualizar GGCE" "error"
        return 1
    fi
    ui::echo-message "Se actualizaron las versiones de forma correcta" "success"
    return 0
 
}