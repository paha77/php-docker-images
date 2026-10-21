#!/usr/bin/env bash
set -euo pipefail
image=$1 platform=$2 kind=$3 minimum=$4
run=(docker run --rm --platform "$platform" --entrypoint /bin/bash "$image")
user=$(docker image inspect --format '{{.Config.User}}' "$image")
[[ "$user" == 1000:0 || "$user" == 1001 ]]
"${run[@]}" -ec 'test "$(id -u)" != 0; php -v; php -r '\''exit(PHP_SAPI === "cli" ? 0 : 1);'\'''
"${run[@]}" -ec 'php -r '\''exit(PHP_MAJOR_VERSION === 8 && PHP_MINOR_VERSION === 2 && version_compare(PHP_VERSION, $argv[1], ">=") ? 0 : 1);'\'' -- "$1"' -- "$minimum"
if [[ "$kind" == cli ]]; then
    modules='gd,exif,mbstring,zip,gmp,bcmath'
else
    modules='apcu,Zend OPcache,pdo_mysql,mbstring'
    "${run[@]}" -ec 'php-fpm -v; php-fpm -t; grep -Eq "^clear_env *= *no" /etc/php-fpm.d/www.conf; rpm -q php-common'
    "${run[@]}" -ec '/usr/libexec/s2i/run-cli php -r '\''exit(ini_get("memory_limit") === "-1" ? 0 : 1);'\'''
fi
"${run[@]}" -ec 'php -r '\''foreach (explode(",", $argv[1]) as $m) { if (!extension_loaded($m)) { fwrite(STDERR, "Missing: $m\n"); exit(1); } }'\'' -- "$1"' -- "$modules"
if [[ "$kind" == dev ]]; then
    "${run[@]}" -ec 'php --ri xdebug; composer --version; test -x /usr/local/bin/wait-for-it.sh; wait-for-file.sh /tmp/nonexistent-check-file'
fi
"${run[@]}" -ec 'test ! -e /root/.ssh; test ! -e /home/appuser/.ssh; test ! -e /opt/app-root/src/.ssh'
