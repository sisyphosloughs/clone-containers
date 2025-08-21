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
        echo "[INFO] Überspringe: '$STACKNAME'"
        return 0
    fi

    # Zielpfad Clone erstellen; Erstellung prüfen
    if [ ! -d "$BACKUP_FOLDER" ]; then
        echo "[INFO] Erstelle Order für Sicherungen: '$BACKUP_FOLDER'"
        mkdir -p "$BACKUP_FOLDER"  || { error_continue; return 1; }
    fi

    # Lösche alte Sicherung, sofern vorhanden
    if [ -e "$BACKUP_FILE" ]; then 
        rm "$BACKUP_FILE" || { error_continue; return 1; }
    fi

    # Starte Backup
    echo "[INFO] Datenbank für $STACKNAME sichern."

    # Überprüft den Typ der Datenbank und führt die entsprechende Backup-Funktion aus
    if [ "$DB_TYP" == "mariadb" ]; then
        
        # Führt das Backup für MariaDB aus
        docker exec -i "$DB_CONTAINER" mariadb-dump -u "$DB_USER" --password="$DB_PASSWORD" $DB_PARAMS > "$BACKUP_FILE" || { error_continue; return 1; }
    
    elif [ "$DB_TYP" == "mysql" ]; then      
    
        # Führt das Backup für MySQL aus
         docker exec -i "$DB_CONTAINER" mysqldump -u "$DB_USER" --password="$DB_PASSWORD" $DB_PARAMS > "$BACKUP_FILE" || { error_continue; return 1; }

    elif [ "$DB_TYP" == "sqlite" ]; then      
    
        # Führt das Backup für SQLite aus
        sqlite3 "$DB_FILE" "VACUUM INTO '$BACKUP_FILE'" || { error_continue; return 1; }
    
    else
    
        # Gibt eine Fehlermeldung aus, wenn kein unterstützter Datenbanktyp gefunden wurde
        echo "[ERROR] Unbekannter oder nicht unterstützter Datenbanktyp '$DB_TYP'"
        error_continue
        return 1
    fi
}

# Prüfe, ob Konfigurationsdateien vorhanden sind
check_instances

# Durchläuft alle .conf Dateien im Verzeichnis
for file in "${INSTANCES[@]}"; do
    clone_wrapper "$file"
done

# Ende
