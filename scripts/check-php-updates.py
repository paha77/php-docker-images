#!/usr/bin/env python3
"""Propose stable PHP patch updates; never change branches or security floors."""

import json
from pathlib import Path
import re
import sys
from urllib.request import urlopen


def latest_patch(current, releases):
    prefix = current.rsplit('.', 1)[0]
    if not isinstance(releases, dict) or not releases:
        raise ValueError('Empty or invalid PHP release response')
    versions = []
    for version in releases:
        if not re.fullmatch(re.escape(prefix) + r'\.\d+', version):
            raise ValueError(f'Unexpected release for {prefix}: {version}')
        versions.append(version)
    return max([current, *versions], key=lambda value: tuple(map(int, value.split('.'))))


def main():
    path = Path('versions.env')
    original = path.read_text()
    updated = original
    changes = []
    for entry in sys.argv[1:]:
        branch, current = entry.split('=', 1)
        if not re.fullmatch(r'\d+\.\d+\.\d+', current):
            raise ValueError(f'Invalid configured version: {current}')
        prefix = current.rsplit('.', 1)[0]
        if branch != prefix.replace('.', ''):
            raise ValueError(f'Branch/version mismatch: {entry}')
        url = f'https://www.php.net/releases/index.php?json&version={prefix}&max=1'
        with urlopen(url, timeout=30) as response:
            latest = latest_patch(current, json.load(response))
        if latest != current:
            pattern = rf'(\[{re.escape(branch)}\]=){re.escape(current)}(?=\s|\))'
            updated, count = re.subn(pattern, lambda match: match[1] + latest, updated)
            if count != 1:
                raise ValueError(f'Expected exactly one version entry for {branch}')
            changes.append(f'- PHP {prefix}: {current} → {latest} ([upstream releases]({url}))')
    if not sys.argv[1:]:
        raise ValueError('Supply configured branch=version arguments')
    # Write only after every branch has been fetched and validated successfully.
    if changes:
        path.write_text(updated)
        Path('php-update-body.md').write_text(
            'New stable PHP patches are available:\n\n' + '\n'.join(changes) +
            '\n\nReview upstream and vendor advisories, then approve the PR workflows '
            'to run both architectures before merging. Vendor packages or official '
            'Docker tags may lag upstream; a failed build must not be bypassed.\n\n'
            'Only PHP patch pins change. Security floors remain enforced. '
            'Merging triggers the normal complete build, validation and publication.\n'
        )


if __name__ == '__main__':
    main()
