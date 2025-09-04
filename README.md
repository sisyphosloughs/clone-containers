# Clone Containers

**Clone Containers** sind eine leichtgewichtige Lösung, um komplette Docker-Stacks regelmäßig zu sichern und auf einem zweiten System lauffähig bereitzustellen.

## Warum?

Im Gegensatz zu klassischen **Datenbankreplikationen** oder komplexen Backup-Strategien, bei denen Daten während des Betriebs konsistent und kontinuierlich synchronisiert werden, verfolgt *Clone Containers* einen pragmatischen Ansatz:

- **Keine Live-Replikation:** Statt einzelne Datenbanken fortlaufend zu spiegeln, werden die gesamten Container-Verzeichnisse kurzzeitig gestoppt, synchronisiert und auf dem Zielsystem als vollständige Kopie bereitgestellt.  
- **Einfache Wiederherstellung:** Das Zielsystem erhält eine 1:1-Kopie aller Container-Daten und kann die Instanzen unabhängig vom Quellsystem starten.  
- **Minimaler Konfigurationsaufwand:** Es sind weder Datenbank-spezifische Replikationsmechanismen noch komplexe Backup-Lösungen erforderlich – nur Docker, `rclone` und zwei Skripte.  

Dieser Ansatz ist besonders geeignet, wenn ein **laufendes Duplikat** des gesamten Docker-Stacks benötigt wird, etwa für Testsysteme, Redundanz-Setups oder schnelle Recovery-Szenarien – ohne sich mit den Details einer kontinuierlichen Datenbankspiegelung beschäftigen zu müssen.

## Übersicht

Die Synchronisierung erfolgt unidirektional mit [Rclone](https://rclone.org): Daten vom Quellcomputer (im Folgenden **Source-Computer**) werden auf den Sicherungscomputer (im Folgenden **Target-Computer**) vollständig übertragen. Dadurch sind Datenbanksicherungen nicht erforderlich. 

Bei der Synchronisierung kommen zwei Skripte zum Einsatz:

- `clone-containers.sh` auf dem Source-Computer: Dieses Skript übernimmt das Stoppen der Container, das Erstellen des Backups und die Übertragung der Daten.
- `restart-containers.sh` auf dem Target-Computer: Dieses Skript prüft den Status und startet die Container auf dem Sicherungscomputer.

> [!NOTE]
> Der Ansatz basiert darauf, dass die Container vom Source- und Target-Computer kurz gestoppt werden. Da für die Übertragung `rclone` verwendet wird, ist die Unterbrechung sehr kurz, da `rclone` nur geänderte Daten übertragen muss.

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
|  optionale Telegram-Info      |     |  optionale Telegram-Info      |
|                               |     |                               |
|  (läuft unabhängig)           |     |  (läuft unabhängig)           |
+-------------------------------+     +-------------------------------+
```

## Voraussetzungen

- Eine lauffähige Docker-Umgebung.
- **Rclone-Installation**: `rclone` muss auf dem Source-Computer vorhanden sein. Installationsanweisungen findest du unter [Rclone-Installationsanweisungen](https://rclone.org/install/).
- **Passwortlose Rclone-Konfiguration**: Richte `rclone`so ein, dass keine Passwortabfrage erforderlich ist.
- Ein Telegram-API-Schlüssel und eine Telegram-Chat-ID für Benachrichtigungen.
- Ein SFTP-Client für `rclone`als Ziel. Zur Minimierung der Angriffsfläche sollte kein SSH, sondern nur SFTP aktiviert sein.
- Für das Logging wird Syslog verwendet. Dadurch ist auch die Auswertung zurückliegender Backups möglich. Falls Syslog auf dem Computer nicht vorhanden ist, sind die Logdateien leer.

## Struktur

Für die Funktionsfähigkeit der Skripte müssen die folgenden Dateien bearbeitet werden:

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

#### Beispiele für Source-Stacks

```conf
# Stack-Name
STACK="example"
# Überspringen, setze hierfür SKIP="true"
# SKIP="true"
# Pfad, der gesichert werden soll
RC_SOURCE_FOLDER="/opt/containers/$STACK"
# Remote-Name (muss in rclone.conf definiert sein)
RC_REMOTE_NAME="example-backup"
# Zielpfad
RC_REMOTE_FOLDER="/var/local/data/clones/$STACK"
# Wenige Ausnahmen definieren, um das Risiko von Fehlkonfigurationen zu vermeiden
RC_EXCEPTIONS=(--exclude=@eaDir/ --exclude=.DS_Store)
# Weitere Parameter, siehe https://rclone.org/flags/
RC_PARAMS="-v --stats-one-line --sftp-md5sum-command=/usr/bin/md5sum --skip-links"
```

#### Beispiele für Target-Stacks

```conf
# Stack-Name
STACK="example"
# Überspringen, setze hierfür SKIP="true"
# SKIP="true"
# Pfad, in dem sich die `docker-compose.yml`-Datei befindet
STACK_DOCKER_COMPOSE="/opt/containers/$STACK"
# Pfad, in dem sich die übertragenen Daten mit der Flag-Datei befinden
STACK_CLONE_DATA="/var/backup/containers/$STACK"
```

### Telegram-Konfiguration

Die Konfigurationsdatei `telegram.secrets` enthält Angaben für Telegram. Selbst wenn kein Versand mit Telegram gewünscht ist, muss eine Pseudo-Konfiguration mit dem Wert `false` für den Schlüssel `TELEGRAM_SEND` vorhanden sein.

Legt die Datei in den jeweils passenden Ordner ab:

- Source-Computer `../clone-containers/source/telegram.secrets`
- Target-Computer `../clone-containers/target/telegram.secrets`

Inhalt der `telegram.secrets`:

```conf
# Der Token für den Telegram-Bot
TELEGRAM_API_TOKEN="your_telegram_bot_token"
# Die Chat-ID für die Benachrichtigungen
TELEGRAM_CHAT_ID="your_chat_id"
# Aktiviert oder deaktiviert das Senden von Benachrichtigungen
TELEGRAM_SEND=true
```

## Installation

### Source-Computer einrichten

1. Lade das Skript zusammen mit dem Unterordner `bash-functions` herunter.
2. Mache die Skript-Datei ausführbar:
    ```sh
    chmod +x source/clone-containers.sh
    chmod +x bash-functions/init.sh
    chmod +x bash-functions/functions.sh
    chmod +x bash-functions/setup_logger.sh
    ```
3. Erstelle die Konfigurationsdateien für die Source-Instanzen (siehe [Beispiele für Source-Stacks](#beispiele-für-source-stacks)).
4. Erstelle die Konfigurationsdatei für die Telegram-Benachrichtigung (siehe [Telegram-Konfiguration](#telegram-konfiguration)).
5. Teste das Backup.
6. Erstelle einen [Crontab-Eintrag](https://de.wikipedia.org/wiki/Cron) für das Skript `clone-containers.sh`. Beispiel:
    ```
    # Docker-Instanzen klonen
    50 5 * * * /home/user/bin/clone-containers/source/clone-containers.sh > /dev/null 2>&1
    ```

### Target-Computer einrichten

> [!NOTE]
> Möglicherweise sind in der `docker-compose.yml` des Source-Computers Pfade oder andere Angaben enthalten, die nicht zum Target-Computer passen. In dem Fall solltest Du eine separate Docker-Konfiguration auf dem Target-Computer mit eigener `docker-compose.yml` anlegen.

1. Lade das Skript zusammen mit dem Unterordner `bash-functions` herunter.
2. Mache die Skript-Datei ausführbar:
    ```sh
    chmod +x target/restart-containers.sh
    chmod +x bash-functions/init.sh
    chmod +x bash-functions/functions.sh
    chmod +x bash-functions/setup_logger.sh
    ```
3. Erstelle die Konfigurationsdateien für die Target-Instanzen (siehe [Beispiele für Target-Stacks](#beispiele-für-target-stacks)).
4. Erstelle die Konfigurationsdatei für die Telegram-Benachrichtigung (siehe [Telegram-Konfiguration](#telegram-konfiguration)).
5. Teste den Neustart.
6. Erstelle einen [Crontab-Eintrag](https://de.wikipedia.org/wiki/Cron) für das Skript `restart-containers.sh`. Beispiel:
    ```
    # Geklonte Docker-Instanzen neustarten
    50 5 * * * /home/user/bin/clone-containers/target/restart-containers.sh > /dev/null 2>&1
    ```
