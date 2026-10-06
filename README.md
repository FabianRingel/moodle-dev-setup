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

- **Moodle**: nginx + PHP 8.3 (FPM), Moodle-Code direkt aus Git (Multi-Stage-Build)
- **PostgreSQL 17**: Relationale Datenbank
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

### Image-Aufbau (Multi-Stage-Build)

Das `Dockerfile` baut das Moodle-Image in mehreren Stages:

| Stage | Inhalt |
|-------|--------|
| `builder` | Kompiliert alle PHP-Erweiterungen (mit `-dev`-Paketen und Compiler) und ermittelt per `ldd` die benötigten Laufzeit-Bibliotheken |
| `base` | Offizielles `php:8.3-fpm-bookworm` + fertige Erweiterungen + nur deren Laufzeit-Bibliotheken – **keine Build-Artefakte** |
| `moodle-source` | Shallow-Fetch des [Moodle-Git-Repositorys](https://github.com/moodle/moodle) in der gewünschten Revision (ohne `.git`) |
| `moodle` | `base` + Moodle-Quellcode + `Docker/config.php`, PHP-FPM auf Port 9000 |
| `web` | `nginx:stable` + nur die öffentlichen Moodle-Dateien (`public/`) + `Docker/nginx.conf.template` |

```bash
# Nur das Base-Image bauen
docker build --target base -t moodle-base .

# Moodle-Image mit bestimmter Version (Branch, Tag oder Commit)
docker build --target moodle --build-arg MOODLE_REF=MOODLE_503_STABLE -t moodle-dev .

# Passendes nginx-Image (gleiche MOODLE_REF verwenden!)
docker build --target web --build-arg MOODLE_REF=MOODLE_503_STABLE -t moodle-web .
```

Build-Argumente:

| Argument | Standard | Beschreibung |
|----------|----------|--------------|
| `PHP_VERSION` | `8.3` | PHP-Version des Basis-Images |
| `DEBIAN_RELEASE` | `bookworm` | Debian-Release des Basis-Images |
| `MOODLE_REPO` | `https://github.com/moodle/moodle.git` | Git-Repository (z.B. eigener Fork) |
| `MOODLE_REF` | `MOODLE_503_STABLE` | Branch, Tag oder Commit |

Ab Moodle 5.1 liegt der Webroot unter `public/`. Das Image erkennt das beim Build
und setzt in nginx `root` sowie den Moodle-Router (`try_files … /r.php`) passend.

### 1. Webserver (`web`)
- **Image**: Stage `web` aus dem `Dockerfile` (nginx)
- Liefert statische Dateien direkt aus und reicht `*.php` per FastCGI an `moodle:9000` weiter
- PHP-FPM-Adresse über die Umgebungsvariable `PHP_FPM_HOST` änderbar (Standard `moodle:9000`)
- Konfiguration: `Docker/nginx.conf.template`

### 2. Moodle Container (`moodle`)
- **Image**: Stage `moodle` aus dem `Dockerfile` (PHP-FPM)
- **FPM-Pool**: `Docker/php-fpm.conf` (u.a. `clear_env = no`, damit `config.php` die Umgebungsvariablen sieht)
- **PHP Extensions**:
  - mysqli, pdo_pgsql, pgsql (Datenbank)
  - gd, imagick (Bildverarbeitung)
  - intl (Internationalisierung)
  - ldap (LDAP-Integration)
  - redis (Caching)
  - opcache (PHP-Optimierung)
  - xdebug (Debugging)
  - zip, soap, xsl, exif (Verschiedene Funktionen)

### 3. PostgreSQL Container (`postgres`)
- **Version**: PostgreSQL 17 (Mindestversion für Moodle 5.3)
- **Standard-Datenbank**: `moodle`
- **Benutzer**: `postgres`
- **Passwort**: `mypwd`

> ⚠️ Ein bestehendes `pgdata/` aus PostgreSQL 13 startet nicht mit PostgreSQL 17.
> Entweder vorher per `pg_dump` sichern und neu einspielen oder `pgdata/` löschen.

### 4. Cron Container (`moodle-cron`)
- **Image**: dasselbe wie `moodle`
- **Funktion**: Führt `admin/cli/cron.php` jede Minute als `www-data` aus

### 5. pgAdmin Container (`pgadmin`)
- **Version**: pgAdmin 4 (neueste)
- **Web-Interface** für Datenbankmanagement
- **Standard-Login**: xxx@xxx.xxx / verysecure

## 🚀 Installation

### 1. Repository klonen

```bash
git clone <repository-url> moodle-dev-setup
cd moodle-dev-setup
```

### 2. Image bauen

Moodle muss nicht mehr manuell heruntergeladen werden – der Code wird beim Build aus Git geholt.

```bash
# Standard-Version (MOODLE_503_STABLE)
docker compose build

# Andere Version
MOODLE_REF=MOODLE_405_STABLE docker compose build
```

### 3. Container starten

```bash
# Container im Hintergrund starten
docker compose up -d

# Container-Status überprüfen
docker compose ps

# Logs anzeigen
docker compose logs -f
```

## ⚙️ Konfiguration

### 1. Moodle-Installation

Die `config.php` ist bereits im Image enthalten. Die Datenbank wird entweder im Browser
(`http://localhost`) oder per CLI installiert:

```bash
docker compose exec -u www-data moodle php admin/cli/install_database.php \
  --agree-license --adminuser=admin --adminpass='Admin1234!' \
  --adminemail=admin@example.com --fullname="Moodle Dev" --shortname=dev
```

### 2. Moodle-Konfiguration (`config.php`)

`Docker/config.php` wird ins Image kopiert und liest alle Werte aus Umgebungsvariablen,
die in `docker-compose.yaml` gesetzt sind:

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `MOODLE_WWWROOT` | `http://localhost` | Öffentliche URL |
| `MOODLE_DB_TYPE` | `pgsql` | Datenbanktyp |
| `MOODLE_DB_HOST` | `postgres` | Datenbank-Host |
| `MOODLE_DB_PORT` | `5432` | Datenbank-Port |
| `MOODLE_DB_NAME` | `moodle` | Datenbankname |
| `MOODLE_DB_USER` | `postgres` | Datenbank-Benutzer |
| `MOODLE_DB_PASSWORD` | – | Datenbank-Passwort |
| `MOODLE_DB_PREFIX` | `mdl_` | Tabellen-Präfix |
| `MOODLE_DATAROOT` | `/var/www/moodledata` | Moodledata-Verzeichnis |
| `MOODLE_DEBUG` | `1` | Developer-Debugging an (`1`) / aus (`0`) |

Weitere Einstellungen direkt in `Docker/config.php` ergänzen und das Image neu bauen.

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
# Der Moodle-Code liegt im Image; Plugins werden per Volume eingehängt
# (siehe Plugin-Entwicklung)

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

- **Moodle (nginx)**: Port 80 → 80
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
                "/var/www/html/public/local/myplugin": "${workspaceFolder}/plugins/local_myplugin"
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

Der Moodle-Core kommt aus dem Image. Eigene Plugins werden als Volume eingehängt
(ab Moodle 5.1 unter `public/`) – und zwar **in beiden Containern**: in `moodle`
für PHP (über `x-moodle.volumes`) und in `web`, damit nginx die statischen Dateien
(Bilder, JS, CSS) des Plugins ausliefern kann:

```yaml
x-moodle: &moodle
  volumes:
    - ./moodledata:/var/www/moodledata
    - ./plugins/local_myplugin:/var/www/html/public/local/myplugin

services:
  web:
    volumes:
      - ./plugins/local_myplugin:/var/www/html/public/local/myplugin
```

```bash
# Plugin-Verzeichnis
mkdir -p plugins/local_myplugin

# Plugin-Installation testen
docker-compose exec -u www-data moodle php /var/www/html/admin/cli/upgrade.php
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
# nginx-Logs (Access- und Error-Log gehen auf stdout/stderr)
docker-compose logs -f web

# PHP-FPM-Logs
docker-compose logs -f moodle

# Cron-Logs
docker-compose logs -f moodle-cron

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
      - ./moodledata:/var/www/moodledata:cached  # macOS-Optimierung
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

