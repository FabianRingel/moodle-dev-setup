# Moodle Development Stack

Ein vollständiger Docker-basierter Entwicklungsstack für Moodle mit PostgreSQL, pgAdmin und automatischen Cron-Jobs.

## 📋 Inhaltsverzeichnis

- [Überblick](#überblick)
- [Voraussetzungen](#voraussetzungen)
- [Stack-Komponenten](#stack-komponenten)
- [Installation](#installation)
- [Konfiguration](#konfiguration)
- [Verwendung](#verwendung)
- [Services und Ports](#services-und-ports)
- [Entwicklung](#entwicklung)
- [Datenbank-Management](#datenbank-management)
- [Troubleshooting](#troubleshooting)
- [Backup und Wiederherstellung](#backup-und-wiederherstellung)
- [Performance-Optimierung](#performance-optimierung)

## 🎯 Überblick

Dieser Development Stack bietet eine vollständige Moodle-Entwicklungsumgebung mit:

- **Moodle**: PHP 8.3 mit Apache-Webserver
- **PostgreSQL 13**: Relationale Datenbank
- **pgAdmin 4**: Web-basierte Datenbankverwaltung
- **Cron Service**: Automatische Ausführung von Moodle-Tasks
- **Persistent Volumes**: Datenpersistierung zwischen Container-Neustarts

## 🔧 Voraussetzungen

### System-Anforderungen

- **Betriebssystem**: macOS, Linux oder Windows mit WSL2
- **RAM**: Mindestens 4 GB (8 GB empfohlen)
- **Speicher**: Mindestens 5 GB freier Festplattenspeicher
- **CPU**: 2+ Kerne empfohlen

### Software-Voraussetzungen

1. **Docker und Docker Compose**
   ```bash
   # Debian/Ubuntu - Docker installieren
   sudo apt update
   sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
   
   # Docker GPG-Schlüssel hinzufügen
   curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
   
   # Docker Repository hinzufügen
   echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   
   # Docker Engine installieren
   sudo apt update
   sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
   
   # Docker ohne sudo verwenden
   sudo usermod -aG docker $USER
   newgrp docker
   
   # Alternativ: Docker Compose V1 installieren (falls benötigt)
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

2. **Installation überprüfen**
   ```bash
   # Docker-Version prüfen
   docker --version
   
   # Docker Compose-Version prüfen (V2)
   docker compose version
   
   # Oder für Docker Compose V1
   docker-compose --version
   
   # Docker-Service starten
   sudo systemctl enable docker
   sudo systemctl start docker
   ```

3. **Git** (für Versionskontrolle)
   ```bash
   # Installation auf Debian/Ubuntu
   sudo apt update
   sudo apt install -y git
   
   # Git konfigurieren
   git config --global user.name "Ihr Name"
   git config --global user.email "ihre.email@example.com"
   ```

4. **Texteditor/IDE** (empfohlen)
   - Visual Studio Code
   - PHPStorm
   - Sublime Text

### Hardware-Empfehlungen

- **Entwicklung**: 8 GB RAM, 4 CPU-Kerne
- **Produktionstest**: 16 GB RAM, 8 CPU-Kerne
- **SSD-Speicher** für bessere Performance

## 🏗️ Stack-Komponenten

### 1. Moodle Container (`moodle`)
- **Base Image**: PHP 8.3 Apache (Debian Bookworm)
- **PHP Extensions**: 
  - mysqli, pdo_pgsql, pgsql (Datenbank)
  - gd, imagick (Bildverarbeitung)
  - intl (Internationalisierung)
  - ldap (LDAP-Integration)
  - redis (Caching)
  - opcache (PHP-Optimierung)
  - xdebug (Debugging)
  - zip, soap, xsl, exif (Verschiedene Funktionen)

### 2. PostgreSQL Container (`postgres`)
- **Version**: PostgreSQL 13
- **Standard-Datenbank**: `moodle`
- **Benutzer**: `postgres`
- **Passwort**: `mypwd`

### 3. Cron Container (`moodle-cron`)
- **Base Image**: PHP 8.3 CLI
- **Funktion**: Führt Moodle Cron-Jobs alle Minute aus
- **Gleiche PHP-Extensions** wie der Moodle-Container

### 4. pgAdmin Container (`pgadmin`)
- **Version**: pgAdmin 4 (neueste)
- **Web-Interface** für Datenbankmanagement
- **Standard-Login**: xxx@xxx.xxx / verysecure

## 🚀 Installation

### 1. Repository klonen/erstellen

```bash
# Projekt-Verzeichnis erstellen
mkdir moodle-dev-setup
cd moodle-dev-setup

# Falls Sie das Projekt klonen:
git clone <repository-url> .
```

### 2. Moodle herunterladen

```bash
# Moodle direkt in das src-Verzeichnis herunterladen
cd src

# Option 1: Git Clone (empfohlen für Entwicklung)
git clone https://github.com/moodle/moodle.git .
cd moodle
git checkout MOODLE_403_STABLE  # oder gewünschte Version

# Option 2: Download als ZIP
wget https://download.moodle.org/download.php/direct/stable403/moodle-latest-403.zip
unzip moodle-latest-403.zip
mv moodle/* .
rm -rf moodle moodle-latest-403.zip

cd ..
```

### 3. Container starten

```bash
# Container im Hintergrund starten
docker-compose up -d

# Container-Status überprüfen
docker-compose ps

# Logs anzeigen
docker-compose logs -f
```

## ⚙️ Konfiguration

### 1. Moodle-Installation

1. **Browser öffnen**: `http://localhost`
2. **Installationsassistent** folgen
3. **Datenbankeinstellungen**:
   - Datenbanktyp: PostgreSQL
   - Host: `postgres`
   - Datenbank: `moodle`
   - Benutzer: `postgres`
   - Passwort: `mypwd`
   - Port: `5432`

### 2. Moodle-Konfiguration (`config.php`)

Nach der Installation erstellen Sie eine `src/config.php`:

```php
<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'postgres';
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'postgres';
$CFG->dbpass    = 'mypwd';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbport' => 5432,
    'dbsocket' => '',
    'dbcollation' => 'utf8_unicode_ci',
);

$CFG->wwwroot   = 'http://localhost';
$CFG->dataroot  = '/var/www/moodledata';
$CFG->admin     = 'admin';

$CFG->directorypermissions = 0777;

// Performance-Optimierungen
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = 'redis';
$CFG->session_redis_port = 6379;

// Debugging (nur für Entwicklung)
$CFG->debug = (E_ALL | E_STRICT);
$CFG->debugdisplay = 1;
$CFG->debugsmtp = 1;

require_once(__DIR__ . '/lib/setup.php');
?>
```

### 3. PHP-Konfiguration anpassen

Die `Docker/php.ini` können Sie nach Bedarf anpassen:

```ini
# Wichtige Einstellungen für Moodle
memory_limit = 512M
post_max_size = 100M
upload_max_filesize = 100M
max_execution_time = 300
max_input_vars = 10000

# Für Entwicklung
display_errors = On
error_reporting = E_ALL
```

## 🎮 Verwendung

### Container-Management

```bash
# Container starten
docker-compose up -d

# Container stoppen
docker-compose down

# Container neustarten
docker-compose restart

# Einzelnen Service neustarten
docker-compose restart moodle

# Container-Logs anzeigen
docker-compose logs -f moodle
docker-compose logs -f postgres
docker-compose logs -f moodle-cron

# In Container einloggen
docker-compose exec moodle bash
docker-compose exec postgres psql -U postgres -d moodle
```

### Entwicklungsworkflow

```bash
# Code-Änderungen werden automatisch synchronisiert
# (Volume-Mount: ./src:/var/www/html/)

# Cache leeren (bei PHP-Änderungen)
docker-compose exec moodle php /var/www/html/admin/cli/purge_caches.php

# Datenbank aktualisieren
docker-compose exec moodle php /var/www/html/admin/cli/upgrade.php --non-interactive

# Admin-Passwort zurücksetzen
docker-compose exec moodle php /var/www/html/admin/cli/reset_password.php --username=admin
```

## 🌐 Services und Ports

| Service | URL/Port | Beschreibung |
|---------|----------|--------------|
| Moodle | http://localhost | Moodle-Installation |
| pgAdmin | http://localhost:8080 | Datenbank-Management |
| PostgreSQL | localhost:5432 | Direkter DB-Zugriff |

### Service-Details

- **Moodle**: Port 80 → 80
- **PostgreSQL**: Port 5432 → 5432
- **pgAdmin**: Port 80 → 8080

## 💻 Entwicklung

### Debugging mit Xdebug

1. **VS Code Konfiguration** (`.vscode/launch.json`):

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Listen for Xdebug",
            "type": "php",
            "request": "launch",
            "port": 9003,
            "pathMappings": {
                "/var/www/html": "${workspaceFolder}/src"
            }
        }
    ]
}
```

2. **Xdebug aktivieren**:

```bash
# In Docker/php.ini hinzufügen:
[xdebug]
xdebug.mode = debug
xdebug.start_with_request = yes
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
```

### Plugin-Entwicklung

```bash
# Plugin-Verzeichnis
mkdir -p src/local/myplugin

# Plugin-Installation testen
docker-compose exec moodle php /var/www/html/admin/cli/upgrade.php
```

### Coding Standards

```bash
# PHP CodeSniffer installieren
docker-compose exec moodle composer global require "squizlabs/php_codesniffer=*"

# Moodle Coding Standards prüfen
docker-compose exec moodle phpcs --standard=moodle /var/www/html/local/myplugin/
```

## 🗄️ Datenbank-Management

### pgAdmin verwenden

1. **Zugriff**: http://localhost:8080
2. **Login**: xxx@xxx.xxx / verysecure
3. **Server hinzufügen**:
   - Name: Moodle DB
   - Host: postgres
   - Port: 5432
   - Database: moodle
   - Username: postgres
   - Password: mypwd

### CLI-Zugriff

```bash
# PostgreSQL CLI
docker-compose exec postgres psql -U postgres -d moodle

# Datenbank-Backup erstellen
docker-compose exec postgres pg_dump -U postgres moodle > backup.sql

# Backup wiederherstellen
docker-compose exec -T postgres psql -U postgres moodle < backup.sql

# Datenbank zurücksetzen
docker-compose exec postgres dropdb -U postgres moodle
docker-compose exec postgres createdb -U postgres moodle
```

### Useful SQL-Queries

```sql
-- Benutzer anzeigen
SELECT username, email, firstname, lastname FROM mdl_user WHERE deleted = 0;

-- Admin-Benutzer erstellen
INSERT INTO mdl_user (username, password, firstname, lastname, email, confirmed) 
VALUES ('admin', MD5('admin123'), 'Admin', 'User', 'admin@localhost.com', 1);

-- Kurse anzeigen
SELECT id, fullname, shortname FROM mdl_course;
```

## 🔧 Troubleshooting

### Häufige Probleme

#### Container startet nicht

```bash
# Container-Status prüfen
docker-compose ps

# Detaillierte Logs anzeigen
docker-compose logs

# Port-Konflikte prüfen
sudo lsof -i :80
sudo lsof -i :5432
sudo lsof -i :8080
```

#### Berechtigungsprobleme

```bash
# Moodledata-Berechtigungen reparieren
sudo chown -R www-data:www-data moodledata/
sudo chmod -R 755 moodledata/

# Oder mit Docker:
docker-compose exec moodle chown -R www-data:www-data /var/www/moodledata/
```

#### Datenbank-Verbindungsfehler

```bash
# Datenbank-Container prüfen
docker-compose exec postgres pg_isready -U postgres

# Verbindung testen
docker-compose exec moodle php -r "
try {
    \$pdo = new PDO('pgsql:host=postgres;dbname=moodle', 'postgres', 'mypwd');
    echo 'Verbindung erfolgreich\n';
} catch (Exception \$e) {
    echo 'Fehler: ' . \$e->getMessage() . '\n';
}
"
```

#### Performance-Probleme

```bash
# Cache leeren
docker-compose exec moodle php /var/www/html/admin/cli/purge_caches.php

# PHP Opcache zurücksetzen
docker-compose restart moodle

# Speicherverbrauch prüfen
docker stats
```

### Log-Dateien

```bash
# Apache-Logs
docker-compose exec moodle tail -f /var/log/apache2/error.log
docker-compose exec moodle tail -f /var/log/apache2/access.log

# PHP-Logs
docker-compose exec moodle tail -f /var/log/php_errors.log

# Cron-Logs
docker-compose exec moodle-cron tail -f /var/log/cron.log

# PostgreSQL-Logs
docker-compose logs postgres
```

## 💾 Backup und Wiederherstellung

### Vollständiges Backup

```bash
#!/bin/bash
# backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups/$DATE"

mkdir -p $BACKUP_DIR

# Datenbank-Backup
echo "Erstelle Datenbank-Backup..."
docker-compose exec -T postgres pg_dump -U postgres moodle > $BACKUP_DIR/database.sql

# Moodledata-Backup
echo "Erstelle Moodledata-Backup..."
tar -czf $BACKUP_DIR/moodledata.tar.gz moodledata/

# Source-Code-Backup (falls lokal modifiziert)
echo "Erstelle Source-Backup..."
tar -czf $BACKUP_DIR/src.tar.gz src/

echo "Backup erstellt in: $BACKUP_DIR"
```

### Wiederherstellung

```bash
#!/bin/bash
# restore.sh

BACKUP_DIR=$1

if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: ./restore.sh /path/to/backup"
    exit 1
fi

# Container stoppen
docker-compose down

# Datenbank wiederherstellen
echo "Stelle Datenbank wieder her..."
docker-compose up -d postgres
sleep 10
docker-compose exec postgres dropdb -U postgres moodle
docker-compose exec postgres createdb -U postgres moodle
docker-compose exec -T postgres psql -U postgres moodle < $BACKUP_DIR/database.sql

# Moodledata wiederherstellen
echo "Stelle Moodledata wieder her..."
rm -rf moodledata/
tar -xzf $BACKUP_DIR/moodledata.tar.gz

# Container neu starten
docker-compose up -d

echo "Wiederherstellung abgeschlossen!"
```

## ⚡ Performance-Optimierung

### Docker-Performance

```yaml
# docker-compose.override.yml für bessere Performance
version: '3.8'
services:
  moodle:
    volumes:
      - ./src:/var/www/html:cached  # macOS-Optimierung
    environment:
      - PHP_OPCACHE_ENABLE=1
      - PHP_OPCACHE_MEMORY_CONSUMPTION=256
      - PHP_OPCACHE_MAX_ACCELERATED_FILES=10000

  postgres:
    environment:
      - POSTGRES_SHARED_BUFFERS=256MB
      - POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
    command: >
      postgres
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c maintenance_work_mem=64MB
      -c checkpoint_completion_target=0.7
      -c wal_buffers=16MB
```

### Moodle-Performance

```php
// In config.php hinzufügen:

// Session-Redis
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = 'redis';
$CFG->session_redis_port = 6379;

// Cache-Konfiguration
$CFG->cachetype = 'redis';
$CFG->cache_redis_server = 'redis:6379';

// Theme-Cache
$CFG->themedesignermode = false;  // Nur für Produktion

// Debugging ausschalten (Produktion)
$CFG->debug = 0;
$CFG->debugdisplay = 0;
```

### System-Monitoring

```bash
# Container-Ressourcen überwachen
docker stats

# Disk-Usage prüfen
du -sh moodledata/
du -sh pgdata/
du -sh src/

# Datenbank-Größe prüfen
docker-compose exec postgres psql -U postgres -d moodle -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;
"
```

---

## 📝 Zusätzliche Hinweise

- **Sicherheit**: Diese Konfiguration ist für Entwicklung optimiert, nicht für Produktion
- **Updates**: Überprüfen Sie regelmäßig auf Updates von Moodle und den Docker-Images
- **Dokumentation**: Siehe [Moodle-Dokumentation](https://docs.moodle.org/) für weitere Details

## 🤝 Support

Bei Problemen:
1. Prüfen Sie die Logs: `docker-compose logs`
2. Konsultieren Sie die [Moodle-Forums](https://moodle.org/forums/)
3. Überprüfen Sie die [Docker-Dokumentation](https://docs.docker.com/)

