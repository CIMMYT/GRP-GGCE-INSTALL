#!/bin/bash

source /usr/lib/cimmyt-ggce-tool/database.sh

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