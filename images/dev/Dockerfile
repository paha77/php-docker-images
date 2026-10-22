ARG COMPOSER_BASE
ARG UBI_IMAGE
FROM ${COMPOSER_BASE} AS composer
FROM ${UBI_IMAGE}
ARG XDEBUG_PACKAGE=php-pecl-xdebug
USER root
RUN yum install -y "${XDEBUG_PACKAGE}" && yum clean all && rm -rf /var/cache/dnf && \
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
