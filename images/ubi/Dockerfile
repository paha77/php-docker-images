ARG UBI_BASE
FROM ${UBI_BASE}
USER root
# Refresh security packages; the release checks still enforce the PHP floor.
RUN sed -i '/override_install_langs=*/d' /etc/yum.conf && \
    yum -y update && yum -y reinstall glibc-common && yum clean all && \
    rm -rf /var/cache/dnf /etc/ssh/ssh_config.d/05-redhat.conf
# Fail on upstream runner drift rather than silently producing a broken CLI runner.
RUN grep -q 'exec httpd -D FOREGROUND' /usr/libexec/s2i/run && \
    sed 's/exec httpd -D FOREGROUND/exec "$@"/g' /usr/libexec/s2i/run > /usr/libexec/s2i/run-cli && \
    chmod 775 /usr/libexec/s2i/run-cli && \
    sed -i '2iexport PHP_MEMORY_LIMIT=-1' /usr/libexec/s2i/run-cli && \
    sed -i 's/.*clear_env[[:space:]]*=.*/clear_env = no/g' /etc/php-fpm.d/www.conf && \
    printf '\ncatch_workers_output = yes\n' >> /etc/php-fpm.d/www.conf && \
    printf 'variables_order = EGPCS\n' > /etc/php.d/99-variables-order.ini && \
    printf 'access.log = /proc/self/fd/2\n' >> /etc/php.d/09-logging.ini
COPY conf/ /opt/app-root/etc/conf.d/
COPY php-pre-start/ /opt/app-root/src/php-pre-start/
COPY status/ /opt/app-root/status/
# RPM updates can reset the writable files required by the non-root S2I runner.
RUN chown 1001:0 /etc/php.ini /etc/php.d/10-opcache.ini && \
    chmod ug+rw /etc/php.ini /etc/php.d/10-opcache.ini && \
    chown -R 1001:0 /var/log/php-fpm && chmod -R ug+rwX /var/log/php-fpm
USER 1001
