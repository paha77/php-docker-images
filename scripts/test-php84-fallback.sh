#!/usr/bin/env bash
# Run inside the disposable php-image-tools container, with the repo at /work.
set -euo pipefail
cd "$(dirname "$0")/.."
test ! -e /etc/yum.repos.d/php84-fallback.repo
mkdir -p /etc/yum.repos.d
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export PATH="$fixture:$PATH" CALLS="$fixture/calls"
cat > "$fixture/rpm" <<'MOCK'
#!/usr/bin/env bash
exit "${RPM_STATUS:-0}"
MOCK
cat > "$fixture/dnf" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CALLS"
if [[ " $* " == *' repoquery '* ]]; then
    [[ ${QUERY_STATUS:-0} == 0 ]] || exit "$QUERY_STATUS"
    [[ ${NATIVE:-0} == 0 ]] || echo php8.4-cli
else
    if [[ " $* " == *' --enablerepo=php84-fallback '* ]]; then
        grep -qx 'includepkgs=php8.4,php8.4-\*' /etc/yum.repos.d/php84-fallback.repo
        grep -qx 'gpgcheck=1' /etc/yum.repos.d/php84-fallback.repo
        grep -qx 'enabled=0' /etc/yum.repos.d/php84-fallback.repo
    else
        test ! -e /etc/yum.repos.d/php84-fallback.repo
    fi
    exit "${UPDATE_STATUS:-0}"
fi
MOCK
chmod +x "$fixture/rpm" "$fixture/dnf"
script=images/ubi/php84/update.sh
RPM_STATUS=1 bash "$script"
test ! -e "$CALLS"
NATIVE=1 bash "$script"
! grep -q -- '--enablerepo=php84-fallback' "$CALLS"
: > "$CALLS"
bash "$script"
grep -q -- '--enablerepo=php84-fallback' "$CALLS"
test ! -e /etc/yum.repos.d/php84-fallback.repo
: > "$CALLS"
if QUERY_STATUS=42 bash "$script"; then exit 1; else test "$?" = 42; fi
! grep -q -- 'upgrade' "$CALLS"
if UPDATE_STATUS=43 bash "$script"; then exit 1; else test "$?" = 43; fi
test ! -e /etc/yum.repos.d/php84-fallback.repo
echo 'PHP 8.4 repository selection and failure tests passed.'
