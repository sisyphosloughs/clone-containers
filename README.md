# Clone Containers

`clone-containers.sh` ist ein Skript zur Automatisierung des Backups von Docker-Containern betrieben. Dabei werden die Container heruntergefahren, um sie vollständig kopieren zu können. Das Skript liest Konfigurationsdateien aus, die spezifische Angaben zu jedem Container enthalten, um ein Backup durchzuführen.

Für das Logging wird Syslog verwendet, was die Auswertung zurückliegender Backups ermöglicht.

## Übersischt

```
+-------------------------------+     +-------------------------------+
|      Computer A (source)      |     |     Computer B (target)       |
|    (clone-containers.sh)      |     |     (restart-containers.sh)   |
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
- **Rclone-Installation**: Rclone muss vorhanden sein. Installationsanweisungen findest Du unter [Rclone-Installationsanweisungen](https://rclone.org/install/).
- **Passwortlose Rclone-Konfiguration**: Richte Rclone so ein, dass keine Passwortabfrage erforderlich ist.
- Ein Telegram-API-Schlüssel und eine Telegram-Chat-ID für Benachrichtigungen.
- Ein SFTP-Client für Rclone als Ziel. Zu Minimierung der Angriffsfläche sollte kein SSH, sondern nur SFTP aktiviert sein.

## Konfiguration

Für die Funktionsfähigkeit des Skripts müssen die folgenden Dateien bearbeitet werden:

```
├── bash-functions
│   ├── functions.sh
│   ├── init.sh
│   ├── README.md
│   └── setup_logger.sh
├── README.md
├── source
│   ├── clone-containers.sh
│   ├── instances
│   │   ├── container.conf.sample  <-- Instanz-Konfigurationsdatei, Beisppiel
│   │   └── your-stack1.conf       <-- Instanz-Konfigurationsdate
│   │   └── your-stack2.conf       <-- Instanz-Konfigurationsdate
│   └── telegram.secrets           <-- Telegram-Konfiguration
└── target
```

### Instanz-Konfigurationsdateien

Das Skript erwartet Konfigurationsdateien im Ordner `instances` mit der Endung `.conf`.

Jede Konfigurationsdatei enthält Schlüssel-Wert-Paare, die das Skript für das Durchführen des Backups benötigt. Die Schlüssel und ihre Bedeutungen werden nachfolgend erläutert:

#### Beispiel

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

1. Lade das Skript zusammen mit dem Unterordner `bash-functions` herunter.
2. Erstelle die Konfigurationsdateien.
3. Teste das Backup.
4. Erstelle einen [Crontab-Eintrag](https://de.wikipedia.org/wiki/Cron) auf dem Computer für das Skript `clone-containers.sh`. Beispiel:
   ```
   # Docker-Instanzen Klonen
   50 5 * * * /home/user/bin/clone-containers/source/clone-containers.sh > /dev/null 2>&1
   ```

