#!/usr/bin/env bash
set -euo pipefail
image=$1 platform=$2 kind=$3 minimum=$4
run=(docker run --rm --platform "$platform" --entrypoint /bin/bash "$image")
user=$(docker image inspect --format '{{.Config.User}}' "$image")
[[ "$user" == 1000:0 || "$user" == 1001 ]]
"${run[@]}" -ec 'test "$(id -u)" != 0; php -v; php -r '\''exit(PHP_SAPI === "cli" ? 0 : 1);'\'''
# Use the same branch/security requirement as the build-time AlmaLinux patch.
docker run --rm -i --platform "$platform" --entrypoint php "$image" /dev/stdin "$minimum" \
    < "$(dirname "$0")/../images/ubi/php-update/check-version.php"
if [[ "$kind" == cli ]]; then
    modules='gd,exif,mbstring,zip,gmp,bcmath'
else
    modules='apcu,Zend OPcache,pdo_mysql,mbstring'
    "${run[@]}" -ec 'php-fpm -v; php-fpm -t; grep -Eq "^clear_env *= *no" /etc/php-fpm.d/www.conf; rpm -qf "$(readlink -f "$(command -v php)")"'
    "${run[@]}" -ec '/usr/libexec/s2i/run-cli php -r '\''exit(ini_get("memory_limit") === "-1" ? 0 : 1);'\'''
fi
"${run[@]}" -ec 'php -r '\''foreach (explode(",", $argv[1]) as $m) { if (!extension_loaded($m)) { fwrite(STDERR, "Missing: $m\n"); exit(1); } }'\'' -- "$1"' -- "$modules"
if [[ "$kind" == dev ]]; then
    "${run[@]}" -ec 'php --ri xdebug; composer --version; test -x /usr/local/bin/wait-for-it.sh; wait-for-file.sh /tmp/nonexistent-check-file'
fi
"${run[@]}" -ec 'test ! -e /root/.ssh; test ! -e /home/appuser/.ssh; test ! -e /opt/app-root/src/.ssh'
