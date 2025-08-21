#!/bin/bash

# Siehe README.md

# Funktionen einfügen
source "$(dirname "$(realpath "$0")")/bash-functions/init.sh"
source "$(dirname "$(realpath "$0")")/bash-functions/functions.sh"
source "$(dirname "$(realpath "$0")")/bash-functions/setup_logger.sh"

clone_wrapper() {
    
    # Konfiguration einlesen
    source_conf "$1"

    # Prüfe ob eine Instanz übersprungen werden soll
    if [ "${SKIP:-}" == "true" ]; then
        echo "[INFO] Überspringe: '$NAME'"
        return 0
    fi
    
}

# Prüfe, ob Konfigurationsdateien vorhanden sind
check_instances

# Durchläuft alle .conf Dateien im Verzeichnis
for file in "${INSTANCES[@]}"; do
    clone_wrapper "$file"
done

# Ende
