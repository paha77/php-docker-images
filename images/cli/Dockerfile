ARG PHP_VERSION
FROM php:${PHP_VERSION}-cli-bookworm
USER root
# Retain extension headers/helpers for compiling additional PHP modules.
RUN mkdir -p /opt/app-root/src && \
    useradd -r -u 1000 --home-dir /home/appuser appuser1 && \
    chown 1000:0 /opt/app-root/src && \
    printf '[PHP]\ndate.timezone = "Europe/Vienna"\n' > /usr/local/etc/php/conf.d/tzone.ini && \
    apt-get update && apt-get install -y --no-install-recommends \
      libfreetype6-dev libjpeg62-turbo-dev libpng-dev libwebp-dev libxpm-dev \
      zlib1g-dev libonig-dev libzip-dev libgmp-dev && \
    docker-php-ext-configure gd --enable-gd --with-webp --with-jpeg --with-xpm --with-freetype && \
    docker-php-ext-install -j"$(nproc)" gd exif mbstring zip gmp bcmath && \
    rm -rf /var/lib/apt/lists/*
USER 1000:0
