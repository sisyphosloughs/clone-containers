# Clone Containers

Clone Containers besteht aus Scripten zur Automatisierung des Backups von Docker-Containern.

Die Synchronisierung erfolgt unidirektional mit `rclone`: Daten vom Quellcomputer (im Folgenden **Source-Computer**) werden auf den Sicherungscomputer (im Folgenden **Target-Computer**) vollständig übertragen. Dadurch sind Datenbanksicherungen nicht erforderlich. 

Bei der Synchronisierung kommen zwei Skripte zum Einsatz:

- `clone-containers.sh` auf dem Source-Computer: Dieses Skript übernimmt das Stoppen der Container, das Erstellen des Backups und die Übertragung der Daten.
- `restart-containers.sh` auf dem Target-Computer: Dieses Skript prüft den Status und startet die Container auf dem Sicherungscomputer.

**Achtung**: Der Ansatz basiert darauf, dass die Container vom Source- und Target-Computer kurz gestoppt werden. Da für die Übertragung `rclone` verwendet wird, ist die Unterbrechung sehr kurz, da `rclone` nur geänderte Daten übertragen muss.

Für das Logging wird Syslog verwendet, was die Auswertung zurückliegender Backups ermöglicht.

## Übersicht

```
+-------------------------------+     +-------------------------------+
|       Source-Computer         |     |        Target-Computer        |
|    (clone-containers.sh)      |     |    (restart-containers.sh)    |
+-------------------------------+     +-------------------------------+
|                               |     |                               |
|  [Crontab-Start]              |     |  [Crontab-Start]              |
|       │                       |     |       │                       |
|       ▼                       |     |       ▼                       |
|  stop Container-Stack         |     |  stop Container-Stack         |
|       │                       |     |       │                       |
|  sync Daten  ─────────────────────────► (Empfängt Daten)            |
|  sync Status-Flag ────────────────────► prüft Status-Flag           |
|       │                       |     |       │                       |
|  start Container-Stack        |     |  start Container-Stack        |
|       │                       |     |       │                       |
|  optional Telegram-Info       |     |  optional Telegram-Info       |
|                               |     |                               |
|  (läuft unabhängig)           |     |  (läuft unabhängig)           |
+-------------------------------+     +-------------------------------+
```

## Voraussetzungen

- Eine lauffähige Docker-Umgebung.
- **Rclone-Installation**: Rclone muss auf dem Source-Computer vorhanden sein. Installationsanweisungen findest Du unter [Rclone-Installationsanweisungen](https://rclone.org/install/).
- **Passwortlose Rclone-Konfiguration**: Richte Rclone so ein, dass keine Passwortabfrage erforderlich ist.
- Ein Telegram-API-Schlüssel und eine Telegram-Chat-ID für Benachrichtigungen.
- Ein SFTP-Client für Rclone als Ziel. Zu Minimierung der Angriffsfläche sollte kein SSH, sondern nur SFTP aktiviert sein.

## Struktur

Für die Funktionsfähigkeit der Skripte müssen die folgende Dateien bearbeitet werden:

```
├── bash-functions
│   ├── functions.sh
│   ├── init.sh
│   ├── README.md
│   └── setup_logger.sh
│
├── README.md
├── source                         <-- Am Source-Computer bearbeiten
│   ├── clone-containers.sh
│   ├── instances
│   │   ├── container.conf.sample  <-- Instanz-Konfigurationsdatei, Beispiel
│   │   └── your-stack1.conf       <-- Instanz-Konfigurationsdatei (nur Source-Computer)
│   │   └── your-stack2.conf       <-- Instanz-Konfigurationsdatei (nur Source-Computer)
│   └── telegram.secrets           <-- Telegram-Konfiguration (nur Source-Computer)
│
└── target                         <-- Am Target-Computer bearbeiten 
│   ├── restart-containers.sh
│   ├── instances
│   │   ├── container.conf.sample  <-- Instanz-Konfigurationsdatei, Beispiel
│   │   └── your-stack1.conf       <-- Instanz-Konfigurationsdatei (nur Target-Computer)
│   │   └── your-stack2.conf       <-- Instanz-Konfigurationsdatei (nur Target-Computer)
│   └── telegram.secrets           <-- Telegram-Konfiguration (nur Target-Computer)
```

### Instanz-Konfigurationsdateien

Das Skript erwartet Konfigurationsdateien im Ordner `instances` mit der Endung `.conf`.

Jede Konfigurationsdatei enthält Schlüssel-Wert-Paare, die das Skript für das Durchführen des Backups benötigt. Die Schlüssel und ihre Bedeutungen werden nachfolgend erläutert:

#### Beispiele

Konfiguration von Source-Stacks:

```conf
# Stack-Name
STACK="example"
# Überspringen, setzte hierfür SKIP="true"
# SKIP="true"
# Pfad, der gesichert werden soll
RC_SOURCE_FOLDER="/opt/containers/$STACK"
# Remote-Name (muss in rclone.conf definiert sein)
RC_REMOTE_NAME="example-backup"
# Zielpfad
RC_REMOTE_FOLDER="/var/local/data/clones/$STACK"
# wenig Ausnahmen definieren, um das Risiko von Fehlkonfigurationen zu vermeiden
RC_EXCEPTIONS=(--exclude=@eaDir/ --exclude=.DS_Store)
# Weitere Parameter, siehe https://rclone.org/flags/
RC_PARAMS="-v --stats-one-line --sftp-md5sum-command=/usr/bin/md5sum --skip-links"
```

Konfiguration von Target-Stacks:

```conf
# Stack-Name
STACK="example"
# Überspringen, setzte hierfür SKIP="true"
# SKIP="true"
# Pfad in dem sich die `docker-compose.yml`-Datei befindet
STACK_DOCKER_COMPOSE="/opt/containers/$STACK"
# Pfad in dem sich die übertragenen Daten mit der Flag-Datei befinden
STACK_DOCKER_COMPOSE="/var/backup/containers/$STACK"
```

### Telegram-Konfiguration

Die Konfigurationsdatei `telegram.secrets` enthält Angaben für Telegram. Selbst wenn kein Versand mit Telegram gewünscht ist, muss eine Pseudo-Konfiguration mit dem Wert `false` für den Schlüssel `TELEGRAM_SEND` vorhanden sein.

Legt die Datei in den jeweils passenden Ordner ab:
- Source-Computer `../clone-containers/source/telegram.secrets`
- Source-Computer `../clone-containers/target/telegram.secrets`

Inhalt der `telegram.secrets`:

```conf
# Der Token für den Telegram-Bot
TELEGRAM_API_TOKEN="your_telegram_bot_token"
# Die Chat-ID für die Benachrichtigungen
TELEGRAM_CHAT_ID="your_chat_id"
# Aktiviert oder deaktiviert das Senden von Benachrichtigungen
TELEGRAM_SEND=true
```

### Installation

Source-Computer:

1. Lade das Skript zusammen mit dem Unterordner `bash-functions` herunter.
2. Erstelle die Konfigurationsdateien.
3. Teste das Backup.
4. Erstelle einen [Crontab-Eintrag](https://de.wikipedia.org/wiki/Cron) auf dem Computer für das Skript `clone-containers.sh`. Beispiel:
   ```
   # Docker-Instanzen Klonen
   50 5 * * * /home/user/bin/clone-containers/source/clone-containers.sh > /dev/null 2>&1
   ```
