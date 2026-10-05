# ==============================================================================
# Moodle Development Image - Multi-Stage Build
# ==============================================================================
#
# Stages:
#   builder        Kompiliert alle PHP-Erweiterungen (inkl. -dev-Pakete, Compiler, …)
#                  und ermittelt die zur Laufzeit benötigten Shared Libraries.
#   base           Schlankes PHP/Apache-Image: nur die fertigen Erweiterungen und
#                  deren Laufzeit-Bibliotheken – keine Build-Artefakte.
#   moodle-source  Holt den Moodle-Quellcode aus dem Git-Repository (ohne .git).
#   moodle         base + Moodle-Quellcode.
#
# Beispiele:
#   docker build --target base   -t moodle-base .
#   docker build --target moodle -t moodle-dev  --build-arg MOODLE_REF=MOODLE_503_STABLE .
#
# ==============================================================================

ARG PHP_VERSION=8.3
ARG DEBIAN_RELEASE=bookworm

# ------------------------------------------------------------------------------
# Stage 1: builder
# ------------------------------------------------------------------------------
FROM php:${PHP_VERSION}-apache-${DEBIAN_RELEASE} AS builder

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions \
      exif \
      gd \
      imagick \
      intl \
      ldap \
      mysqli \
      opcache \
      pdo_pgsql \
      pgsql \
      redis \
      soap \
      xdebug \
      xsl \
      zip

# Alle Debian-Pakete ermitteln, deren Shared Libraries von den gebauten
# Erweiterungen gelinkt werden. Nur diese landen später im base-Image.
RUN set -eux; \
    ext_dir="$(php-config --extension-dir)"; \
    find "$ext_dir" -name '*.so' -exec ldd {} + 2>/dev/null \
      | awk '$2 == "=>" && $3 ~ /^\// { print $3 }' \
      | sort -u \
      | while read -r lib; do \
          dpkg-query -S "*/$(basename "$lib")" 2>/dev/null | cut -d: -f1 | cut -d, -f1; \
        done \
      | grep -v -- '-dev$' \
      | sort -u > /runtime-packages.txt; \
    cat /runtime-packages.txt

# ------------------------------------------------------------------------------
# Stage 2: base – PHP + Apache ohne Build-Artefakte
# ------------------------------------------------------------------------------
FROM php:${PHP_VERSION}-apache-${DEBIAN_RELEASE} AS base

COPY --from=builder /runtime-packages.txt /tmp/runtime-packages.txt

RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    xargs -a /tmp/runtime-packages.txt apt-get install -y --no-install-recommends; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/runtime-packages.txt

COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/     /usr/local/etc/php/conf.d/

COPY ./Docker/php.ini /usr/local/etc/php/php.ini

RUN set -eux; \
    a2enmod headers rewrite actions; \
    mkdir -p /var/www/moodledata; \
    chown www-data:www-data /var/www/moodledata; \
    # Sicherstellen, dass alle Erweiterungen ohne fehlende Libraries laden
    php -m > /tmp/php-modules; \
    for ext in exif gd imagick intl ldap mysqli pdo_pgsql pgsql redis soap sodium xdebug xsl zip "Zend OPcache"; do \
      grep -qx "$ext" /tmp/php-modules || { echo "PHP-Erweiterung fehlt: $ext" >&2; exit 1; }; \
    done; \
    rm /tmp/php-modules

# ------------------------------------------------------------------------------
# Stage 3: moodle-source – Moodle-Code aus dem Git-Repository holen
# ------------------------------------------------------------------------------
FROM alpine/git AS moodle-source

# Branch, Tag oder Commit des Moodle-Repositories
ARG MOODLE_REPO=https://github.com/moodle/moodle.git
ARG MOODLE_REF=MOODLE_503_STABLE

# Shallow-Fetch genau einer Revision; .git wird nicht ins Image übernommen
RUN set -eux; \
    git init -q /moodle; \
    git -C /moodle fetch -q --depth 1 "$MOODLE_REPO" "$MOODLE_REF"; \
    git -C /moodle checkout -q FETCH_HEAD; \
    rm -rf /moodle/.git

# ------------------------------------------------------------------------------
# Stage 4: moodle – base + Moodle-Code
# ------------------------------------------------------------------------------
FROM base AS moodle

COPY --from=moodle-source --chown=www-data:www-data /moodle /var/www/html

# config.php liest die Einstellungen aus Umgebungsvariablen (siehe docker-compose.yaml)
COPY --chown=www-data:www-data ./Docker/config.php /var/www/html/config.php

# Ab Moodle 5.1 liegt der Webroot im Unterordner public/ und Moodle nutzt
# einen Router (r.php). Apache wird passend zur ausgecheckten Version konfiguriert.
RUN set -eux; \
    if [ -d /var/www/html/public ]; then docroot=/var/www/html/public; else docroot=/var/www/html; fi; \
    sed -ri "s!/var/www/html!${docroot}!g" /etc/apache2/sites-available/*.conf; \
    { \
      echo "<Directory ${docroot}>"; \
      echo "    AllowOverride All"; \
      if [ -f "${docroot}/r.php" ]; then echo "    FallbackResource /r.php"; fi; \
      echo "</Directory>"; \
    } > /etc/apache2/conf-available/moodle.conf; \
    a2enconf moodle
