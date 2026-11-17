#!/usr/bin/env bash
set -euo pipefail

# Other UBI branches retain their existing package-update path.
rpm -q php8.4-cli >/dev/null 2>&1 || exit 0
ubi_repos=(--disablerepo='*' --enablerepo='ubi-10-for-*-baseos-rpms'
    --enablerepo='ubi-10-for-*-appstream-rpms'
    --enablerepo='codeready-builder-for-ubi-10-*-rpms')
# Do not interpret a metadata/network failure as missing PHP packages.
available=$(dnf -q "${ubi_repos[@]}" --refresh repoquery --available --qf '%{name}' php8.4-cli)
if grep -qx php8.4-cli <<< "$available"; then
    echo 'Public UBI offers PHP 8.4; using UBI packages only.'
    dnf -y "${ubi_repos[@]}" upgrade 'php8.4' 'php8.4-*'
    exit 0
fi

echo 'Public UBI lacks PHP 8.4; using signed AlmaLinux EL10 PHP 8.4 packages only.'
repo=/etc/yum.repos.d/php84-fallback.repo
trap 'rm -f "$repo"' EXIT
cat > "$repo" <<'REPO'
[php84-fallback]
name=AlmaLinux EL10 PHP 8.4 fallback
baseurl=https://repo.almalinux.org/almalinux/10/AppStream/$basearch/os/
enabled=0
gpgcheck=1
gpgkey=file:///tmp/php84/RPM-GPG-KEY-AlmaLinux-10
includepkgs=php8.4,php8.4-*
skip_if_unavailable=0
REPO
# UBI supplies all non-PHP dependencies; never enable a general clone repository.
dnf -y "${ubi_repos[@]}" --enablerepo=php84-fallback upgrade 'php8.4' 'php8.4-*'
