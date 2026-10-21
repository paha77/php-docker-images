# Reusable PHP images

| Docker Hub image | Purpose | Parent |
| --- | --- | --- |
| paha77/php-82-cli | PHP CLI with GD, EXIF, mbstring, ZIP, GMP, BCMath and Europe/Vienna timezone | Official PHP CLI, Debian Bookworm |
| paha77/s2i-ubi9-php82 | Apache/FPM, S2I CLI runner, status endpoints, prelogin | Red Hat UBI 9 PHP 8.2 |
| paha77/php-82-dev | Xdebug, Composer, wait scripts and local UID aliases | Freshly built custom UBI |

All releases target `linux/amd64` and `linux/arm64/v8` (including M1 Macs).
This repository builds, validates and publishes these three PHP images independently.

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

Review security releases immediately; weekly refreshes fetch updated OS packages
with no build cache. Version tags should be advanced deliberately after reviewing
vendor changes. Add separately named PHP 8.5 CLI/UBI/dev images (at least the
advisory's 8.5.12) once UBI provides that branch. Validate extensions, FPM, Composer
and CLI runner behavior on both platforms before retiring the 8.2 images; complete
this migration before 8.2 EOL.

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

CLI retains extension headers and docker-php-ext helpers for compiling additional
modules. Its runtime default is UID 1000:0; UBI/dev use UID 1001. Derived Dockerfiles
installing packages must explicitly use `USER root`, then restore a non-root user.
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

Consume any of the three images by its published name and tag. Pin a validated
immutable release tag or manifest digest for reproducibility; `latest` tracks the
most recently validated release.

## GitHub setup

### Choose the Docker Hub namespace

Publication defaults to `paha77`. To publish a fork's images to your own Docker Hub
account or organization, open **Settings → Secrets and variables → Actions →
Variables → New repository variable** and set `DOCKERHUB_NAMESPACE` to your namespace
(for example, `yourname`). This publishes `yourname/php-82-cli`,
`yourname/s2i-ubi9-php82` and `yourname/php-82-dev`, including all release and alias
tags. Create those three Docker Hub repositories and use credentials with push
access to them. In the setup instructions below, replace `paha77` with your chosen
namespace and use your fork's GitHub repository address for GitHub CLI commands.

The namespace is separate from `DOCKERHUB_USERNAME`, which identifies the login
account and may differ when publishing to an organization. It is not a secret.
The publication script also accepts `DOCKERHUB_NAMESPACE` as an environment
variable, defaulting to `paha77` when unset or empty. Local build tags and the dev
image's freshly built UBI parent are unchanged.

### Obtain Docker Hub credentials

1. Sign in to [Docker Home](https://app.docker.com/) with the Docker ID that owns
   `paha77`, or an account with push access to that namespace. Verify the account's
   email address. Create `paha77/php-82-cli`, `paha77/s2i-ubi9-php82` and
   `paha77/php-82-dev` on Docker Hub before enabling publication.
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
and generate a token with read/write access limited to the three repositories,
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
before publishing. Configure secrets, then review and commit the build files
to enable the workflow. GitHub CLI is optional setup tooling, not a build dependency:

```sh
gh secret set DOCKERHUB_USERNAME --repo paha77/php-docker-images
gh secret set DOCKERHUB_TOKEN --repo paha77/php-docker-images
git add .
git commit -m "Add multi-architecture PHP image builds"
git push -u origin main
gh workflow enable images.yml --repo paha77/php-docker-images
gh workflow run images.yml --repo paha77/php-docker-images --ref main
```

Enable Actions in repository settings, protect the default branch, require the image
build check and review workflow changes. The first default-branch push publishes
automatically if secrets are already configured. Watch its result before consuming
any tag. No application deployment is performed.

## Implementation validation status

Shell syntax checks passed. Docker execution was blocked by local socket access;
builds, actual ARM64 execution, base-image availability and pushed manifest checks
remain unverified until the first successful CI run. No images have been published.
