#!/usr/bin/env bash
set -euo pipefail

minimum=${1:?Expected PHP minimum version}
check="$(dirname "$0")/check-version.php"
# Normal UBI updates have already run. Patch only an unmet version requirement.
if php "$check" "$minimum"; then
    echo 'UBI PHP satisfies the version requirement; no AlmaLinux patch needed.'
    exit 0
else
    status=$?
    # A missing/broken PHP runtime or wrong branch is not a patchable version gap.
    [[ $status == 1 ]] || exit "$status"
fi
case "$minimum" in
    8.2.*)
        generation=9; include='php-8.2.*,php-*-8.2.*'; packages=('php-8.2.*' 'php-*-8.2.*')
        ubi_repos=(--enablerepo=ubi-9-baseos-rpms --enablerepo=ubi-9-appstream-rpms
            --enablerepo=ubi-9-codeready-builder-rpms) ;;
    8.4.*)
        generation=10; include='php8.4,php8.4-*'; packages=(php8.4 'php8.4-*')
        ubi_repos=(--enablerepo='ubi-10-for-*-baseos-rpms' --enablerepo='ubi-10-for-*-appstream-rpms'
            --enablerepo='codeready-builder-for-ubi-10-*-rpms') ;;
    *) exit 2 ;;
esac
echo "Applying signed AlmaLinux EL$generation PHP-only patch for $minimum."
repo=/etc/yum.repos.d/php-fallback.repo
trap 'rm -f "$repo"' EXIT
cat > "$repo" <<REPO
[php-fallback]
name=AlmaLinux PHP version patch
baseurl=https://repo.almalinux.org/almalinux/$generation/AppStream/\$basearch/os/
enabled=0
gpgcheck=1
gpgkey=file:///tmp/php-update/RPM-GPG-KEY-AlmaLinux-$generation
includepkgs=$include
module_hotfixes=1
skip_if_unavailable=0
REPO
# Only public UBI may supply non-PHP dependencies. No stream changes or erasures.
dnf -y --disablerepo='*' "${ubi_repos[@]}" \
    --enablerepo=php-fallback --setopt='*.skip_if_unavailable=False' \
    upgrade "${packages[@]}"
# Fail inside the build if the patch was absent, too old, or broke the runtime.
php "$check" "$minimum"
