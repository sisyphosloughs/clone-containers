# Webserver-Backup von Datenbanken

`backupdb.sh` ist ein Skript zur Automatisierung des Backups von Datenbanken, die in Docker-Containern betrieben werden. Es unterstützt MariaDB- und SQLite-Datenbanken und bietet die Möglichkeit, Backup-Benachrichtigungen über Telegram zu versenden. Das Skript liest Konfigurationsdateien aus, die spezifische Angaben zu jeder Datenbank enthalten, um ein Backup durchzuführen.

Für das Logging wird Syslog verwendet, was die Auswertung zurückliegender Backups ermöglicht.

## Voraussetzungen

- Eine lauffähige Docker-Umgebung.
- Ein Telegram-API-Key und eine Telegram-Chat-ID für Benachrichtigungen.
- Eine Linux-Distribution, die `journalctl` unterstützt, z.B. Ubuntu.

## Konfiguration

Für die Funktionsfähigkeit des Skripts müssen die folgenden Dateien bearbeitet werden:

```
├── backupdb.sh
├── bash-functions
│   ├── functions.sh
│   ├── init.sh
│   ├── README.md
│   └── setup_logger.sh
├── instances
│   ├── mariadb1.conf  <-- Instanz-Konfigurationsdatei
│   ├── mariadb2.conf  <-- Instanz-Konfigurationsdatei
│   └── sqlite.conf    <-- Instanz-Konfigurationsdatei
├── README.md
└── telegram.secrets   <-- Telegram-Konfiguration
```

### Instanz-Konfigurationsdateien

Das Skript erwartet Konfigurationsdateien im Ordner `instances` mit der Endung `.conf`.

Jede Konfigurationsdatei enthält Schlüssel-Wert-Paare, die das Skript für das Durchführen des Backups benötigt. Die Schlüssel und ihre Bedeutungen werden nachfolgend erläutert:

#### MariaDB-Konfiguration

```conf
# Überspringen, setzte hierfür SKIP="true"
# SKIP="true"
# Der Typ der Datenbank, unterstützt "mariadb"
DB_TYP="mariadb"
# Der Name des Stacks, wird für Container-Namen und Pfade verwendet
STACKNAME="example-stack" 
# Der Pfad, wo der Docker-Stack gespeichert ist
STACKPATH="/opt/containers/example-stack/"
# Der Name des Datenbank-Containers, abgeleitet vom Stack-Namen
DB_CONTAINER="${STACKNAME}-db"
# Der Benutzername für die Datenbank-Anmeldung
DB_USER="username"
# Das Passwort für den Datenbank-Benutzer, ausgelesen aus einer Datei
DB_PASSWORD="$(< "$STACKPATH/mysql_root.secret")"
# Die Parameter für den Dump-Befehl
DB_PARAMS="--all-databases --single-transaction --skip-lock-tables" 
# Der Zielpfad für das Backup
BACKUP_FOLDER="/path/to/backups/"
# Der Dateiname für das Backup
BACKUP_FILE="$BACKUP_FOLDER/${DB_CONTAINER}.sql" 
```

#### SQLite-Konfiguration

```conf
# Der Typ der Datenbank, unterstützt "sqlite"
DB_TYP="sqlite"
# Der Name des Stacks, wird für Container-Namen und Pfade verwendet
STACKNAME="example-stack" 
# Der Pfad, wo der Docker-Stack gespeichert ist
STACKPATH="/opt/containers/$STACKNAME/"
# Der Pfad und Name der SQLite-Datenbankdatei
DB_FILE="$STACKPATH/data/db.sqlite3"
# Der Zielpfad für das Backup
BACKUP_FOLDER="/path/to/backups/"
# Der Dateiname für das Backup
BACKUP_FILE="$BACKUP_FOLDER/$STACKNAME.sqlite3"
```

### Telegram-Konfiguration

Die Konfigurationsdatei `telegram.secrets` enthält Angaben für Telegram. Selbst wenn kein Versand mit Telegram gewünscht ist, sollte eine Pseudo-Konfiguration mit dem Wert `false` für den Schlüssel `TELEGRAM_SEND` vorhanden sein.

```conf
# Der Token für den Telegram-Bot
TELEGRAM_API_TOKEN="your_telegram_bot_token"
# Die Chat-ID für die Benachrichtigungen
TELEGRAM_CHAT_ID="your_chat_id"
# Aktiviert oder deaktiviert das Senden von Benachrichtigungen
TELEGRAM_SEND=true
```

### Installation

1. Laden Sie das Skript zusammen mit dem Unterordner `bash-functions` herunter.
2. Erstellen Sie Konfigurationsdateien.
3. Testen Sie das Backup.

## Überwachung

```bash
journalctl -t backupdb.sh
```

## Anpassung

Falls Sie weitere Datenbanktypen unterstützen möchten, können Sie dafür eine Funktion schreiben und den Aufruf in die Funktion `db_wrapper` integrieren. In den entsprechenden Konfigurationsdateien muss der Typ im Schlüssel `DB_TYP` angegeben werden.