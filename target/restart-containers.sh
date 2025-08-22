#!/bin/bash

# Dieses Skript synchronisiert Docker-Container mit einem 
# Remote-Speicherort und verwaltet deren Status.
# Mehr siehe README.md

# Debugging
# set -x

# Externe Funktionen und Logger einbinden
source "$(dirname "$(realpath "$0")")/../bash-functions/init.sh"
source "$(dirname "$(realpath "$0")")/../bash-functions/functions.sh"
source "$(dirname "$(realpath "$0")")/../bash-functions/setup_logger.sh"

# Funktion: restart_wrapper
# Zweck: Startet eine Docker-Instanz neu, falls der die Flag-Datei vorhand
restart_wrapper() {
    
    # Konfiguration einlesen
    source_conf "$1"

    # Prüfe ob eine Instanz übersprungen werden soll
    if [ "${SKIP:-}" == "true" ]; then
        echo "[INFO] Überspringe: '$STACK'"
        return 0
    fi

    # Prüfe ob Synchronisation erfolgreich war
    if [ ! -f "$STACK_CLONE_DATA/CLONE-SUCCESS" ]; then
        echo "[ERROR] Keine CLONE-SUCCESS-Datei gefunden für: $STACK, überspringe Neustart."
        error_continue
        return 1
    fi

    # Instanz stoppen
    echo "[INFO] Stoppe Instanz: $STACK"
    docker compose -f "$STACK_DOCKER_COMPOSE/docker-compose.yml" down
    if [ $? -ne 0 ]; then
        echo "[ERROR] Konnte Instanz nicht stoppen: $STACK"
        error_continue
        return 1
    else
        echo "[INFO] Instanz gestoppt: $STACK"

        # Instanz starten
        echo "[INFO] Starte Instanz: $STACK"
        docker compose -f "$STACK_DOCKER_COMPOSE/docker-compose.yml" up -d
        if [ $? -ne 0 ]; then
            echo "[ERROR] Konnte Instanz nicht starten: $STACK"
            error_continue
            return 1
        else
            echo "[INFO] Instanz gestartet: $STACK"
        fi

    fi

}

# Prüfe, ob Konfigurationsdateien vorhanden sind
check_instances

# Durchläuft alle .conf Dateien im Verzeichnis
for file in "${INSTANCES[@]}"; do
    restart_wrapper "$file"
done

# Ende