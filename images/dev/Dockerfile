ARG COMPOSER_BASE
ARG UBI_IMAGE
ARG PHP_VERSION
FROM php:${PHP_VERSION}-cli-bookworm AS xdebug
ARG XDEBUG_PACKAGE=php-pecl-xdebug
ARG XDEBUG_SOURCE_VERSION
# UBI lacks PHP 8.4 development headers; build with the matching PHP ABI instead.
RUN mkdir /xdebug && \
    if [ -z "$XDEBUG_PACKAGE" ]; then \
        MAKEFLAGS="-j$(nproc)" pecl install "xdebug-${XDEBUG_SOURCE_VERSION}" && \
        cp "$(php-config --extension-dir)/xdebug.so" /xdebug/xdebug.so; \
    fi
FROM ${COMPOSER_BASE} AS composer
FROM ${UBI_IMAGE}
ARG XDEBUG_PACKAGE=php-pecl-xdebug
USER root
COPY --from=xdebug /xdebug/ /usr/lib64/php/modules/
RUN if [ -n "$XDEBUG_PACKAGE" ]; then \
        yum install -y "${XDEBUG_PACKAGE}"; \
    else \
        printf 'zend_extension=xdebug.so\n' > /etc/php.d/15-xdebug.ini; \
    fi && \
    php --ri xdebug >/dev/null && \
    yum clean all && rm -rf /var/cache/dnf && \
    printf '\nxdebug.mode=debug,develop\nxdebug.discover_client_host=true\n' >> /etc/php.d/15-xdebug.ini && \
    useradd -r -u 1000 --home-dir /home/appuser appuser1 && \
    useradd -r -u 501 --home-dir /home/appuser appuser2 && \
    mkdir -p /home/appuser/.config vendor && chmod -R a+w /home/appuser && chmod 775 vendor && \
    chown 1001:0 /etc/php.ini /etc/php.d/10-opcache.ini && \
    chmod ug+rw /etc/php.ini /etc/php.d/10-opcache.ini && \
    chown -R 1001:0 /var/log/php-fpm && chmod -R ug+rwX /var/log/php-fpm
COPY --chmod=755 scripts/ /usr/local/bin/
COPY --from=composer /usr/bin/composer /usr/bin/composer
ENV HOME=/home/appuser
USER 1001
