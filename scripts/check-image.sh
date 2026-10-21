#!/usr/bin/env bash
set -euo pipefail
image=$1 platform=$2 kind=$3 minimum=$4
run=(docker run --rm --platform "$platform" --entrypoint /bin/bash "$image")
user=$(docker image inspect --format '{{.Config.User}}' "$image")
[[ "$user" == 1000:0 || "$user" == 1001 ]]
"${run[@]}" -ec 'test "$(id -u)" != 0; php -v; php -r '\''exit(PHP_SAPI === "cli" ? 0 : 1);'\'''
# Enforce the branch and advisory floor independently of configurable base versions.
# CVE-2026-109618 and CVE-2026-109619 (21 October 2026).
"${run[@]}" -ec 'php -r '\''
    $branch = implode(".", array_slice(explode(".", $argv[1]), 0, 2));
    $floors = ["8.2" => "8.2.35", "8.4" => "8.4.27"];
    $actualBranch = PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;
    if (!isset($floors[$branch]) || $actualBranch !== $branch ||
        !version_compare(PHP_VERSION, $floors[$branch], ">=") ||
        !version_compare(PHP_VERSION, $argv[1], ">=")) {
        fwrite(STDERR, "PHP " . PHP_VERSION . " fails branch/security minimum for " . $argv[1] . "\n");
        exit(1);
    }
'\'' -- "$1"' -- "$minimum"
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
