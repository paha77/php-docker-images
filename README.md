# Reusable PHP images

| Docker Hub image | Purpose | Parent |
| --- | --- | --- |
| paha77/php-82-cli | PHP CLI extensions and Vienna timezone | Official PHP CLI, Debian Bookworm |
| paha77/s2i-ubi9-php82 | Apache/FPM, S2I CLI runner, status endpoints, prelogin | Red Hat UBI 9 PHP 8.2 |
| paha77/php-82-dev | Xdebug, Composer, wait scripts and local UID aliases | Freshly built custom UBI |

These reusable images are independent of application code.

## Security and updates

`versions.env` owns the PHP minimum/exact official base patch, UBI version tag,
and Composer version. The [PHP advisory](https://www.php.net/archive/2026.php#2026-10-21-5)
requires PHP 8.2.35. PHP 8.2 security support ends 31 December 2026.
The [UBI catalog](https://catalog.redhat.com/en/software/containers/ubi9/php-82/657b0176999f2e3662c8159b)
lists version `1-1792440794`; its architecture availability and fixed PHP package
availability have **not** been confirmed locally. The Red Hat pages for
[CVE-2026-109618](https://access.redhat.com/security/cve/CVE-2026-109618) and
[CVE-2026-109619](https://access.redhat.com/security/cve/CVE-2026-109619)
were inaccessible during implementation. No vendor backport exception is used.
UBI updates packages during build, then must pass the same upstream version floor.
If either architecture lacks a fixed base/package, the workflow fails before login
or publication. Review vendor advisories, update versions.env as needed, and retry
with workflow_dispatch. Never lower the floor merely to get a green build.

Review security releases immediately. Maintain a tested upgrade path to a supported PHP branch before PHP 8.2 reaches end of security support.

## Build and validation

Docker Engine/Desktop with Buildx and a running daemon is the only host dependency.
Docker Desktop supplies emulation. On Linux install binfmt using the same QEMU
setup as CI before running cross-platform checks. A containerized tool wrapper is
provided so Bash/jq need not be installed on the host:

```sh
docker build -t php-image-tools tools
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/work" -w /work php-image-tools scripts/build.sh
```

The default Buildx **docker driver** loads each architecture under its own local
tag. The dev build consumes that exact local UBI tag, never Docker Hub latest.
All three images on both architectures execute PHP, check the release floor and
extensions, verify non-root defaults, and check common credential locations.
UBI/dev also validate FPM configuration and unlimited-memory CLI runner behavior;
dev checks Composer, Xdebug and wait scripts. Build contexts are allowlisted.
These are focused checks, not a full forensic audit of inherited vendor layers.

CLI retains extension headers and helpers for additional module builds. Runtime defaults remain non-root. Never inject SSH keys into builds. The metrics script assumes cgroup v1.

## Releases and automation

Pull requests and branch pushes build all images without publishing. Default-branch
pushes, Monday 05:23 UTC schedules, and manual runs on the default branch build,
validate, then authenticate and publish. PR steps receive no registry credentials;
there is no shared cache. Publishing runs serialize in one concurrency group.
Only full-SHA-pinned checkout and QEMU actions are used. Their release commits were
checked against upstream GitHub release pages; review source before updating pins.

Each repository gets these tags:

* `php8.2.35-<full-source-sha>-run<run-id>.<attempt>`: unique release manifest.
* The same release tag plus `-amd64` or `-arm64`: platform staging images.
* `php8.2.35` and `latest`: mutable, validated multi-platform compatibility aliases.

Configure Docker Hub immutable-tag rules for the `*-run*` release/staging tags where
supported; never reuse them. The run identity distinguishes scheduled package
refreshes without source changes. UBI can report a later 8.2 patch than the tag's
minimum; runtime checks and rpm output record what was built. All immutable
manifests pass before aliases are promoted. Registries offer no transaction across
repositories: a network failure during promotion can update only some aliases;
the job fails and a new dispatch safely republishes a complete release.

Inspect a release (replace TAG with the actual workflow tag):

```sh
docker buildx imagetools inspect paha77/php-82-dev:TAG
docker run --rm --platform linux/amd64 --entrypoint php paha77/php-82-dev:TAG -v
docker run --rm --platform linux/arm64/v8 --entrypoint php paha77/php-82-dev:TAG -v
docker run --rm --platform linux/arm64/v8 --entrypoint php-fpm paha77/php-82-dev:TAG -t
```

Expected manifest excerpt, **illustrative, not an observed build result**:

```text
Platform: linux/amd64
Platform: linux/arm64/v8
```

These reusable images are independent of application code.

## GitHub setup

No repository, remote, commit or publication was created. Local `git init -b main`
was attempted but filesystem policy denied creation of `.git`. Complete it locally.
Choose OWNER/REPO yourself and obtain its SSH URL; no remote name is assumed here.
The following are developer-run commands, after review (GitHub CLI is optional
setup tooling, not a build dependency):

```sh
git init -b main
gh repo create OWNER/REPO --private
git remote add origin git@github.com:OWNER/REPO.git
gh secret set DOCKERHUB_USERNAME --repo OWNER/REPO
gh secret set DOCKERHUB_TOKEN --repo OWNER/REPO
git add .
git commit -m "Add multi-architecture PHP image builds"
git push -u origin main
gh workflow enable images.yml --repo OWNER/REPO
gh workflow run images.yml --repo OWNER/REPO --ref main
```

Create the three Docker Hub repositories under paha77 first, and confirm ownership.
Use a dedicated token with read/write access to only these repositories where
Docker Hub supports repository-scoped tokens; no delete scope. Enter secrets only
at the CLI prompts or GitHub Settings → Secrets and variables → Actions. Enable
Actions in repository settings, protect the default branch, require the image
build check and review workflow changes. The first default-branch push publishes
automatically if secrets are already configured. Watch its result before consuming
any tag. No application deployment is performed.

## Implementation validation status

Shell syntax checks passed. Docker execution was blocked by local socket access;
builds, actual ARM64 execution, base-image availability and pushed manifest checks
remain unverified until the first successful CI run. No images have been published.
