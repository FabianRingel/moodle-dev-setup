# Verwenden des offiziellen PHP 8.3 Apache-Images als Basis
FROM php:8.3-apache-bookworm

# Installation der MySQL-Erweiterung, Systembibliotheken, Apache-Modulen, PHP-Erweiterungen und Redis in einem Schritt
RUN docker-php-ext-install -j$(nproc) mysqli \
  && apt-get update -y && apt-get upgrade -y && apt-get install -y \
    gpg \
    imagemagick \
    libc-client-dev \
    libct4 \
    libcurl4-openssl-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libldap2-dev \
    libmagickwand-dev \
    libpng-dev \
    libpq-dev \
    libsybdb5 \
    libxml2-dev \
    libxslt-dev \
    libzip-dev \
    tdsodbc \
    unixodbc-dev \
    zlib1g-dev \
  && apt-get clean -y \
  && a2enmod headers rewrite actions \
  && docker-php-ext-configure gd --with-jpeg \
  && docker-php-ext-install -j$(nproc) gd \
  && docker-php-ext-install -j$(nproc) xsl \
  && docker-php-ext-install -j$(nproc) soap \
  && docker-php-ext-install -j$(nproc) pdo_pgsql \
  && docker-php-ext-install -j$(nproc) intl \
  && docker-php-ext-install -j$(nproc) pgsql \
  && docker-php-ext-install -j$(nproc) ldap \
  && docker-php-ext-install -j$(nproc) opcache \
  && docker-php-ext-install -j$(nproc) exif \
  && docker-php-ext-install -j$(nproc) zip \
  && pecl install redis \
  && docker-php-ext-enable redis \
  && rm -rf /var/lib/apt/lists/*

# Imagick
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions imagick/imagick@master && docker-php-ext-enable imagick \
    && pecl install xdebug && docker-php-ext-enable xdebug

# Kopieren der PHP-Konfiguration
COPY ./Docker/php.ini /usr/local/etc/php/php.ini

# Optional: Kopieren des Quellcodes in das Apache-Webverzeichnis
COPY --chown=www-data:www-data /src /var/www/html/