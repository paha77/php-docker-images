#!/usr/bin/env bash
# Run inside the disposable php-image-tools container, with the repo at /work.
set -euo pipefail
cd "$(dirname "$0")/.."
test ! -e /etc/yum.repos.d/php-fallback.repo
mkdir -p /etc/yum.repos.d
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export PATH="$fixture:$PATH" CALLS="$fixture/calls"
cat > "$fixture/php" <<'MOCK'
#!/usr/bin/env bash
if test -e "$CALLS.updated"; then exit "${PATCH_STATUS:-0}"; fi
exit "${INITIAL_STATUS:-0}"
MOCK
cat > "$fixture/dnf" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CALLS"
repo=/etc/yum.repos.d/php-fallback.repo
grep -Fxq "includepkgs=$EXPECTED_INCLUDE" "$repo"
grep -Fxq 'gpgcheck=1' "$repo"
grep -Fxq 'enabled=0' "$repo"
grep -Fq "/almalinux/$EXPECTED_GENERATION/AppStream/" "$repo"
grep -Fxq 'module_hotfixes=1' "$repo"
if [[ $EXPECTED_GENERATION == 9 ]]; then
    [[ " $* " == *' --enablerepo=ubi-9-appstream-rpms '* ]]
else
    [[ " $* " == *' --enablerepo=ubi-10-for-*-appstream-rpms '* ]]
fi
[[ " $* " == *' --disablerepo=* '* && " $* " == *' --enablerepo=php-fallback '* ]]
touch "$CALLS.updated"
exit "${UPDATE_STATUS:-0}"
MOCK
chmod +x "$fixture/php" "$fixture/dnf"
script=images/ubi/php-update/update.sh
for minimum in 8.2.35 8.4.27; do
    if [[ $minimum == 8.2.* ]]; then
        export EXPECTED_GENERATION=9 EXPECTED_INCLUDE='php-8.2.*,php-*-8.2.*'
    else
        export EXPECTED_GENERATION=10 EXPECTED_INCLUDE='php8.4,php8.4-*'
    fi
    rm -f "$CALLS" "$CALLS.updated"
    bash "$script" "$minimum"
    test ! -e "$CALLS"
    for status in 2 127; do
        if INITIAL_STATUS=$status bash "$script" "$minimum"; then exit 1; else test "$?" = "$status"; fi
        test ! -e "$CALLS"
    done
    INITIAL_STATUS=1 bash "$script" "$minimum"
    test -s "$CALLS"
    test ! -e /etc/yum.repos.d/php-fallback.repo
    rm -f "$CALLS.updated"
    if INITIAL_STATUS=1 UPDATE_STATUS=43 bash "$script" "$minimum"; then exit 1; else test "$?" = 43; fi
    test ! -e /etc/yum.repos.d/php-fallback.repo
    rm -f "$CALLS.updated"
    if INITIAL_STATUS=1 PATCH_STATUS=1 bash "$script" "$minimum"; then exit 1; else test "$?" = 1; fi
    test ! -e /etc/yum.repos.d/php-fallback.repo
done
echo 'PHP version patch selection and failure tests passed.'
