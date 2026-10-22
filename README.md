# Reusable PHP images

| Docker Hub image | Purpose | Parent |
| --- | --- | --- |
| paha77/php-82-cli | PHP CLI with GD, EXIF, mbstring, ZIP, GMP, BCMath and Europe/Vienna timezone | Official PHP CLI, Debian Bookworm |
| paha77/s2i-ubi9-php82 | Apache/FPM, S2I CLI runner, status endpoints, prelogin | Red Hat UBI 9 PHP 8.2 |
| paha77/php-82-dev | Xdebug, Composer, wait scripts and local UID aliases | Freshly built custom UBI |
| paha77/php-84-cli | Same CLI extensions, timezone and user as 8.2 CLI | Official PHP 8.4 CLI, Debian Bookworm |
| paha77/s2i-ubi10-php84 | Apache/FPM, S2I CLI runner, status endpoints, prelogin | Red Hat UBI 10 PHP 8.4 |
| paha77/php-84-dev | Xdebug, Composer, wait scripts and local UID aliases | Freshly built custom UBI 10 PHP 8.4 |

All releases target `linux/amd64` and `linux/arm64/v8` (including M1 Macs).
This repository builds, validates and publishes both branches; the existing 8.2
repositories and aliases remain in place.

## Security and updates

`versions.env` owns the branch list, PHP minimum/exact official base patches, UBI
bases/generations, Xdebug package names and Composer version. It is a Bash config
with associative arrays (Bash 4+); use the Docker tools wrapper on macOS.
The [PHP advisory](https://www.php.net/archive/2026.php#2026-10-21-5)
requires PHP 8.2.35 and 8.4.27 for CVE-2026-109618 and CVE-2026-109619.
The runtime gate independently enforces those floors and the expected branch,
even if a configured minimum is lowered. PHP 8.2 security support ends
31 December 2026. PHP 8.4 active support ends 31 December 2026 and security support
ends 31 December 2028; see the [upstream schedule](https://www.php.net/supported-versions.php).
The [UBI catalog](https://catalog.redhat.com/en/software/containers/ubi9/php-82/657b0176999f2e3662c8159b)
lists version `1-1792440794`; an amd64 build with package updates still reported
PHP 8.2.33 and failed the security gate. The Red Hat pages for
[CVE-2026-109618](https://access.redhat.com/security/cve/CVE-2026-109618) and
[CVE-2026-109619](https://access.redhat.com/security/cve/CVE-2026-109619)
were inaccessible during implementation. No vendor backport exception is used.
UBI updates packages during build, then must pass the same upstream version floor.
The new UBI 10 base is pinned by multi-platform digest. Its manifest includes
amd64 and arm64/v8; an ARM64 base inspection executed PHP 8.4.24, which is below
the floor. The public UBI repository query did not offer a PHP 8.4 update or
matching Xdebug package. Builds with package updates still executed PHP 8.4.24
on both architectures. These remain release blockers until Red Hat supplies the
fixed packages for both architectures; base availability alone is insufficient.
Review the configured 8.4 Xdebug package name when the vendor supplies it;
`php8.4-pecl-xdebug` is currently unavailable. The available PHP 8.3 Xdebug package
is not a substitute.
If either architecture lacks a fixed base/package, the workflow fails before login
or publication. Review vendor advisories, update versions.env as needed, and retry
with workflow_dispatch. Never lower the floor merely to get a green build.

Review security releases immediately; weekly refreshes fetch updated OS packages
with no build cache. Version tags should be advanced deliberately after reviewing
vendor changes. Migrate consumers to the separately named 8.4 images only after
extensions, FPM, Composer and CLI runner behavior pass on both platforms. Retain
8.2 images during migration and complete migration before 8.2 EOL. PHP 8.5 images
are deferred: neither UBI 9 nor UBI 10 currently has a `php-85` repository.

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
tag: `local/php-{cli,ubi,dev}:{82,84}-{amd64,arm64}`. The dev build consumes
that exact branch and architecture's local UBI tag, never Docker Hub latest.
For a single image, `scripts/build.sh KIND BRANCH ARCH` selects `cli`, `ubi` or
`dev`, a configured branch (`82` or `84`), and `amd64` or `arm64`. Run this through
the same Docker tools wrapper. A selected dev build requires its freshly built
UBI parent to be loaded first. With no arguments, the script still builds and
validates all images in dependency order.
All six images on both architectures execute PHP, check the release floor and
extensions, verify non-root defaults, and check common credential locations.
UBI/dev also validate FPM configuration and unlimited-memory CLI runner behavior;
dev checks Composer, Xdebug and wait scripts. Build contexts are allowlisted.
These are focused checks, not a full forensic audit of inherited vendor layers.

CLI retains extension headers and docker-php-ext helpers for compiling additional
modules. Its runtime default is UID 1000:0; UBI/dev use UID 1001. Derived Dockerfiles
installing packages must explicitly use `USER root`, then restore a non-root user.
UBI and dev restore UID 1001 ownership and owner/group write access to
`/etc/php.ini`, `/etc/php.d/10-opcache.ini` and `/var/log/php-fpm` after package
installation. RPM updates can reset these permissions; the S2I runner needs them
to apply runtime settings, including the unlimited CLI memory limit.
Build-time SSH-key injection is excluded. Status/prelogin hooks are included in
the UBI image; the metrics script currently assumes cgroup v1. When both
`PRELOGIN_USER` and `PRELOGIN_PASSWORD` are set, the prelogin hook requires the
`x-prelogin-auth` header containing the Basic authentication value, except for
OPTIONS requests. Supply credentials only at runtime.

## Public repository policy

Keep source, documentation, examples, and Git history free of private project
names, paths, domains, infrastructure details, credential values, and personal
contact information other than the approved Git author name/email. The image
names and repository address documented here are the public identifiers of this
project. Documented environment variable and
Actions secret names are configuration interfaces; their values must stay private.

Before changing visibility, audit all branches and tags, commit author/committer
metadata, pull requests, issues, releases, wiki pages, and Actions logs/artifacts.
Deleting a reference in a later commit does not remove it from history. Any
history replacement requires explicit authorization and a separate review before
publication. Never make the repository public while historical disclosures remain.

## Releases and automation

Pull requests and branch pushes build all images without publishing. Default-branch
pushes, Monday 05:23 UTC schedules, and manual runs on the default branch build,
validate, then authenticate and publish. PR steps receive no registry credentials;
there is no shared cache. Publishing runs serialize in one concurrency group.
The workflow derives branch/platform matrices from `versions.env`. CLI and UBI
have separate jobs for each branch and architecture, with matrix fail-fast
disabled so other images still report their results. After that matrix succeeds,
dev jobs load their exact UBI parent from the same workflow run and build and
validate each dev image separately. A final **Docker push** job waits for every
build and validation to succeed, loads all twelve image archives before login,
then runs the existing publication script. A missing archive fails publication.
The push job is skipped for PRs and non-default branches.

Validated images are transferred with `docker save`/`docker load` using compressed
GitHub Actions artifacts, retained for one day. Artifact names include kind,
branch and architecture; rerun builds replace that run's matching artifacts.
Rerun the entire workflow after artifacts expire. No images are pushed to Docker
Hub for transfer between jobs. GitHub artifact storage limits must accommodate
the twelve image archives. No new secrets or host dependencies are required.
Checkout, QEMU and artifact actions are pinned by full SHA; the new artifact pins
and action source were checked against the official upstream repositories.
Review source before updating pins.

Each repository gets these tags:

* `php<VERSION>-<full-source-sha>-run<run-id>.<attempt>`: unique release manifest,
  where VERSION is `8.2.35` or `8.4.27` for the corresponding repository.
* The same release tag plus `-amd64` or `-arm64`: platform staging images.
* `php<VERSION>` and `latest`: mutable, validated multi-platform compatibility aliases
  within each branch's separate repositories.

Configure Docker Hub immutable-tag rules for the `*-run*` release/staging tags where
supported; never reuse them. The run identity distinguishes scheduled package
refreshes without source changes. UBI can report a later 8.2 patch than the tag's
minimum (likewise for 8.4); runtime checks and rpm output record what was built.
All six immutable manifests pass before aliases are promoted. Registries offer no
transaction across repositories: a network failure during promotion can update only some aliases;
the job fails and a new dispatch safely republishes a complete release.

Inspect a release (replace TAG with the actual workflow tag):

```sh
docker buildx imagetools inspect paha77/php-82-dev:TAG
docker run --rm --platform linux/amd64 --entrypoint php paha77/php-82-dev:TAG -v
docker run --rm --platform linux/arm64/v8 --entrypoint php paha77/php-82-dev:TAG -v
docker run --rm --platform linux/arm64/v8 --entrypoint php-fpm paha77/php-82-dev:TAG -t
# Use an 8.4 release tag for the new repositories:
docker buildx imagetools inspect paha77/s2i-ubi10-php84:TAG
docker run --rm --platform linux/amd64 --entrypoint php paha77/php-84-cli:TAG -v
docker run --rm --platform linux/arm64/v8 --entrypoint php paha77/php-84-dev:TAG -v
docker run --rm --platform linux/arm64/v8 --entrypoint php-fpm paha77/php-84-dev:TAG -t
```

Expected manifest excerpt, **illustrative, not an observed build result**:

```text
Platform: linux/amd64
Platform: linux/arm64/v8
```

Consume any of the six images by its published name and tag. Pin a validated
immutable release tag or manifest digest for reproducibility; `latest` tracks the
most recently validated release.

## GitHub setup

### Choose the Docker Hub namespace

Publication defaults to `paha77`. To publish a fork's images to your own Docker Hub
account or organization, open **Settings → Secrets and variables → Actions →
Variables → New repository variable** and set `DOCKERHUB_NAMESPACE` to your namespace
(for example, `yourname`). This publishes `yourname/php-82-cli`,
`yourname/s2i-ubi9-php82`, `yourname/php-82-dev`, `yourname/php-84-cli`,
`yourname/s2i-ubi10-php84` and `yourname/php-84-dev`, including all release and alias
tags. Create those six Docker Hub repositories and use credentials with push
access to them. In the setup instructions below, replace `paha77` with your chosen
namespace and use your fork's GitHub repository address for GitHub CLI commands.

The namespace is separate from `DOCKERHUB_USERNAME`, which identifies the login
account and may differ when publishing to an organization. It is not a secret.
The publication script also accepts `DOCKERHUB_NAMESPACE` as an environment
variable, defaulting to `paha77` when unset or empty. Namespace selection does not
affect local build tags or the dev image's freshly built UBI parent.

### Obtain Docker Hub credentials

1. Sign in to [Docker Home](https://app.docker.com/) with the Docker ID that owns
   `paha77`, or an account with push access to that namespace. Verify the account's
   email address. Create `paha77/php-82-cli`, `paha77/s2i-ubi9-php82` and
   `paha77/php-82-dev`, `paha77/php-84-cli`, `paha77/s2i-ubi10-php84` and
   `paha77/php-84-dev` on Docker Hub before enabling publication.
2. Open your avatar → **Account settings** → **Personal access tokens** →
   **Generate new token**. Give it a dedicated description such as
   `php-docker-images GitHub Actions` and choose an expiration date.
3. Grant repository **Read & Write** access without Delete permission; leave
   unrelated product access disabled. A personal access token applies to all
   repositories the account can access, so use an account with limited access
   where practical. See Docker's [personal access token instructions](https://docs.docker.com/security/access-tokens/personal-access-tokens/).
4. Generate the token and copy it into a password manager immediately: Docker
   displays it only once. Use this token instead of your Docker account password.

If `paha77` is an organization with a Docker Team or Business subscription, prefer
an [organization access token](https://docs.docker.com/security/access-tokens/organization-access-tokens/):
select the organization in Docker Home → **Identity & auth** → **Access tokens**
and generate a token with read/write access limited to the six repositories,
without delete or organization administration permissions. For this token type,
use the organization name as the login username.

### Set GitHub Actions secrets

In the GitHub repository, open **Settings → Secrets and variables → Actions →
New repository secret** and create these two secrets (not Actions variables):

| Secret name | Value |
| --- | --- |
| `DOCKERHUB_USERNAME` | Docker ID that issued the personal token (for example, `paha77`), not an email address; for an organization token, the organization name |
| `DOCKERHUB_TOKEN` | The generated access token |

Alternatively, use the two `gh secret set` commands below and enter each value at
its prompt. Never put the token in a command argument, committed file, build
argument or workflow log. Local `docker login` is not required for CI: the workflow
reads these secrets only in the publication step after validation. Before the
token expires, create a replacement, update `DOCKERHUB_TOKEN`, and revoke the old
token after a successful publication with the replacement.

### Enable the workflow

The Git repository is initialized and its SSH remote is
`git@github.com:paha77/php-docker-images.git`. Inspect current Git status and history
before publishing. Review the committed build files and configure secrets before
pushing to enable the workflow. GitHub CLI is optional setup tooling, not a build dependency:

```sh
gh secret set DOCKERHUB_USERNAME --repo paha77/php-docker-images
gh secret set DOCKERHUB_TOKEN --repo paha77/php-docker-images
git push -u origin main
gh workflow enable images.yml --repo paha77/php-docker-images
gh workflow run images.yml --repo paha77/php-docker-images --ref main
```

Enable Actions in repository settings, protect the default branch, require the
new per-image build checks in place of the former single `images` check, and
review workflow changes. The first default-branch push publishes
automatically if secrets are already configured. Watch its result before consuming
any tag. No application deployment is performed.

## Implementation validation status

The workflow split passed containerized Actionlint 1.7.7, shell syntax and
whitespace checks. A Docker tools harness with a mock Docker command checked all
twelve selections, the no-argument build path, invalid selectors, missing-parent
failure and validation failure propagation. The split has not yet executed on
GitHub; artifact transfer and publication remain unverified there.

On 22 October 2026, the permission fix passed the full existing UBI 9 checks on
amd64 and arm64/v8 with updated PHP 8.2.35 packages. The amd64 build used no cache.
The PHP 8.2 dev image also passed on both architectures using each freshly built
UBI parent.
These checks supersede the earlier UBI 9 version blocker described below.
The latest CI run before this fix reached PHP 8.2.35, then failed the CLI runner
memory check after permission errors; publication was skipped.
PHP 8.4 release blockers below have not been rechecked as part of this fix.

Shell syntax and Git whitespace checks passed. Docker-only checks executed the
8.4.27 CLI image on amd64 and arm64/v8 successfully. The 8.2.35 CLI image also
passed on amd64.
UBI 10 builds completed on amd64 and arm64/v8; FPM configuration, expected
extensions and the unlimited-memory CLI runner passed isolated compatibility
checks on both platforms. Both UBI 10 builds failed the PHP floor with 8.4.24.
Negative gate tests also rejected a lowered minimum and a mismatched branch.
The full build stopped on UBI 9 amd64 reporting PHP 8.2.33. An ARM64 8.4 dev build
failed because the configured matching Xdebug package is unavailable. Dev runtime
validation and a complete successful build remain blocked. No images were pushed
or published during these checks; published manifests remain unverified.
