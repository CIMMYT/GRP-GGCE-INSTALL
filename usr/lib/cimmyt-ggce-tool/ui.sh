#!/bin/bash

ui::echo-message(){
    local message="$1"
    local severity="${2:-none}"

    case "$severity" in
        success)
            echo "✅ Exito: $message"
        ;;
        warning)
            echo "⚠️ Advertencia: $message"
        ;;
        error)
            echo "❌ Error: $message" >&2
        ;;
        help)
            echo "📖 $message"
        ;;
        *)
            echo "❯ $message"
        ;;


    esac


}