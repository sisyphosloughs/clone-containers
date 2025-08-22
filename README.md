# Clone Containers

`clone-containers.sh` ist ein Skript zur Automatisierung des Backups von Docker-Containern betrieben. Dabei werden die Container heruntergefahren, um sie vollständig kopieren zu können. Das Skript liest Konfigurationsdateien aus, die spezifische Angaben zu jedem Container enthalten, um ein Backup durchzuführen.

Für das Logging wird Syslog verwendet, was die Auswertung zurückliegender Backups ermöglicht.

## Übersischt

```
+-------------------------------+     +-------------------------------+
|          Computer A           |     |          Computer B           |
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
- Ein Telegram-API-Key und eine Telegram-Chat-ID für Benachrichtigungen.
- Eine Linux-Distribution, die `journalctl` unterstützt, z.B. Ubuntu.

## Konfiguration

Für die Funktionsfähigkeit des Skripts müssen die folgenden Dateien bearbeitet werden:

```
├── clone-contaiers.sh
├── bash-functions
│   ├── functions.sh
│   ├── init.sh
│   ├── README.md
│   └── setup_logger.sh
├── instances
│   ├── container1.conf  <-- Instanz-Konfigurationsdatei
│   ├── container2.conf  <-- Instanz-Konfigurationsdatei
│   └── container3.conf  <-- Instanz-Konfigurationsdatei
├── README.md
└── telegram.secrets     <-- Telegram-Konfiguration
```

### Instanz-Konfigurationsdateien

Das Skript erwartet Konfigurationsdateien im Ordner `instances` mit der Endung `.conf`.

Jede Konfigurationsdatei enthält Schlüssel-Wert-Paare, die das Skript für das Durchführen des Backups benötigt. Die Schlüssel und ihre Bedeutungen werden nachfolgend erläutert:

#### Beispiel

```conf
# Name
NAME="vaultwarden"
# Pfad, der gesichert werden soll
RC_SOURCE_FOLDER="/volume1/Backup/Milos/containers/$NAME"
# Remote-Name
RC_REMOTE_NAME="$NAME"
# Zielpfad
RC_REMOTE_FOLDER="/var/local/data/clones/$NAME"
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
2. Erstelle Konfigurationsdateien.
3. Teste das das Backup.
4. Erstelle einen [Crontab-Eintrag](https://de.wikipedia.org/wiki/Cron) auf dem Computer für das Script `clone-contaiers.sh`.
