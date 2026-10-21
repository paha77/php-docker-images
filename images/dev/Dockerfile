ARG COMPOSER_BASE
ARG UBI_IMAGE
FROM ${COMPOSER_BASE} AS composer
FROM ${UBI_IMAGE}
USER root
RUN yum install -y php-pecl-xdebug && yum clean all && rm -rf /var/cache/dnf && \
    printf '\nxdebug.mode=debug,develop\nxdebug.discover_client_host=true\n' >> /etc/php.d/15-xdebug.ini && \
    useradd -r -u 1000 --home-dir /home/appuser appuser1 && \
    useradd -r -u 501 --home-dir /home/appuser appuser2 && \
    mkdir -p /home/appuser/.config vendor && chmod -R a+w /home/appuser && chmod 775 vendor
COPY --chmod=755 scripts/ /usr/local/bin/
COPY --from=composer /usr/bin/composer /usr/bin/composer
ENV HOME=/home/appuser
USER 1001
