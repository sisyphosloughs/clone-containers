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

# Funktion: clone_wrapper
# Zweck: Synchronisiert eine Docker-Instanz mit einem Remote-Speicherort
# Parameter: $1 - Pfad zur Konfigurationsdatei der Instanz
clone_wrapper() {
    
    # Konfiguration einlesen
    source_conf "$1"

    # Prüfe ob eine Instanz übersprungen werden soll
    if [ "${SKIP:-}" == "true" ]; then
        echo "[INFO] Überspringe: '$STACK'"
        return 0
    fi

    # Instanz stoppen
    echo "[INFO] Stoppe Instanz: $STACK"
    docker compose -f "$RC_SOURCE_FOLDER/docker-compose.yml" down
    if [ $? -ne 0 ]; then
        echo "[ERROR] Konnte Instanz nicht stoppen: $STACK"
        error_continue
        return 1
    else
        echo "[INFO] Instanz gestoppt: $STACK"
    fi

    # Synchronisiere
    echo "[INFO] Sync $STACK"
    echo "--------------------------------------------------------"
    rclone sync "${RC_EXCEPTIONS[@]}" $RC_PARAMS "$RC_SOURCE_FOLDER" "$RC_REMOTE_NAME":"$RC_REMOTE_FOLDER" || error_continue
    echo "--------------------------------------------------------"
    # ERROR_FLAG setzen, wenn rclone Fehler zurückgibt
    if [ $? -ne 0 ]; then
        ERROR_FLAG=1
        error_continue
    else
        ERROR_FLAG=0
    fi

    # Prüfe, ob die Synchronisation erfolgreich war
    echo "[INFO] Check $STACK"
    echo "--------------------------------------------------------"
    rclone check "${RC_EXCEPTIONS[@]}" $RC_PARAMS "$RC_SOURCE_FOLDER" "$RC_REMOTE_NAME":"$RC_REMOTE_FOLDER" || error_continue
    echo "--------------------------------------------------------"
    # ERROR_FLAG setzen, wenn rclone Fehler zurückgibt
    if [ $? -ne 0 ]; then
        ERROR_FLAG=1
        error_continue
    fi

    # FLAG-DATEI erstellen
    # Die Flag-Datei wird im Quellordner erstellt und dann zum Remote-Ordner kopiert
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    if [ $ERROR_FLAG -eq 1 ]; then
        CLONE_STATUS_NAME="CLONE-FAILED"
        echo "[INFO] Erstelle Flag-Datei: $CLONE_STATUS_NAME"
        echo "Last sync attempt: $TIMESTAMP" > "$RC_SOURCE_FOLDER/$CLONE_STATUS_NAME"
        rclone copy "$RC_SOURCE_FOLDER/$CLONE_STATUS_NAME" "$RC_REMOTE_NAME":"$RC_REMOTE_FOLDER"
    else
        CLONE_STATUS_NAME="CLONE-SUCCESS"
        echo "[INFO] Erstelle Flag-Datei: $CLONE_STATUS_NAME"
        echo "Last sync: $TIMESTAMP" > "$RC_SOURCE_FOLDER/$CLONE_STATUS_NAME"
        rclone copy "$RC_SOURCE_FOLDER/$CLONE_STATUS_NAME" "$RC_REMOTE_NAME":"$RC_REMOTE_FOLDER"
    fi

    # Instanz starten
    echo "[INFO] Starte Instanz: $STACK"
    docker compose -f "$RC_SOURCE_FOLDER/docker-compose.yml" up -d
    if [ $? -ne 0 ]; then
        echo "[ERROR] Konnte Instanz nicht starten: $STACK"
        error_continue
        return 1
    else
        echo "[INFO] Instanz gestartet: $STACK"
    fi

}

# Prüfe, ob Konfigurationsdateien vorhanden sind
check_instances

# Durchläuft alle .conf Dateien im Verzeichnis
for file in "${INSTANCES[@]}"; do
    clone_wrapper "$file"
done

# Ende