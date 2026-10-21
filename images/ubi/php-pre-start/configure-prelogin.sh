#!/bin/bash

set +u # Expands non existing env vars to an empty string, fixes "unbound var" issues if no pre login is set
if [ -n "${PRELOGIN_USER}" ] && [ -n "${PRELOGIN_PASSWORD}" ]; then
    echo "RewriteEngine on" >> /opt/app-root/etc/conf.d/prelogin.conf
    echo "RewriteCond %{REQUEST_METHOD} !OPTIONS" >> /opt/app-root/etc/conf.d/prelogin.conf
    echo "RewriteCond %{HTTP:x-prelogin-auth} !^Basic\s`echo -n $PRELOGIN_USER:$PRELOGIN_PASSWORD | base64`$ [NC]" >> /opt/app-root/etc/conf.d/prelogin.conf
    echo "RewriteRule ^ - [F]" >> /opt/app-root/etc/conf.d/prelogin.conf
fi
set -u
