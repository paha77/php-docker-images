# Agent instructions and repository context

## Scope

This standalone repository builds reusable PHP images. Do not inspect or modify external repositories or consumers. Do not start application containers or deploy images.

| Image | Build context | Responsibility |
| --- | --- | --- |
| `paha77/php-82-cli` | `images/cli` | Official PHP CLI with GD, EXIF, mbstring, ZIP, GMP, BCMath; Europe/Vienna timezone; UID 1000:0 |
| `paha77/s2i-ubi9-php82` | `images/ubi` | UBI 9 Apache/FPM, S2I CLI runner, status/prelogin hooks; UID 1001 |
| `paha77/php-82-dev` | `images/dev` | Custom UBI plus Xdebug, Composer, wait scripts and UID aliases; UID 1001 |

CLI builds independently. Dev must consume the custom UBI image built for the
same architecture in the same run, never an old published `latest`.
Keep these registry names unless a concrete ownership/access issue requires a
migration; explain any proposed registry migration before implementing it.

## Start of a session

Read this file, README.md, versions.env and the files relevant to the requested
change. Inspect `git status --short` before editing. Preserve all existing
uncommitted changes. Inspect first, then choose the smallest complete change.
Reuse the current architecture, workflows and configuration layers; do not
refactor unrelated code or introduce unnecessary dependencies.

Docker is the only required host dependency for builds and checks. Use direct
file editing, not sed/Perl/Python one-liners to edit repository files. Shell
transformations inside Dockerfiles are intentional build operations.
Minimize external requests and authentication attempts; inspect failures before
retrying. Ask when a consequential requirement is genuinely ambiguous; otherwise
execute authorized work and necessary checks without repeated confirmation.

## Build and release architecture

- `versions.env` centralizes PHP_VERSION, UBI_BASE and COMPOSER_BASE. Avoid
  duplicating version configuration. Keep base images version-pinned or digest-pinned
  where practical, with deliberate security updates.
- `scripts/build.sh` uses the default Buildx **docker driver**, loading separate
  `local/php-{cli,ubi,dev}:{amd64,arm64}` tags. Do not switch builders without
  preserving dev's ability to resolve the freshly built local UBI parent.
- Every image targets `linux/amd64` and `linux/arm64/v8`. ARM64 must actually
  execute, including on an emulated CI runner; an amd64-only build is insufficient.
- `.github/workflows/images.yml` builds all images on PRs and pushes. Default-branch
  pushes, Monday 05:23 UTC schedules and workflow_dispatch on the default branch
  publish after validation. Other branches and PRs never publish.
- GitHub-hosted Ubuntu runners use SHA-pinned checkout and QEMU actions. Review
  upstream action source and full commit IDs before updating pins.
- Registry secrets are exposed only to the trusted publication step, after checks.
  Never use pull_request_target to run untrusted code with credentials. No shared
  build cache is currently used; any future cache must isolate untrusted PRs.
- Publishing runs serialize through workflow concurrency. Fail closed on build,
  authentication, execution, manifest validation or push failures; never skip an
  unavailable platform and report success.
- `scripts/publish.sh` pushes architecture tags and checks each release manifest
  before updating any compatibility aliases. Tags are
  `php<VERSION>-<full-source-sha>-run<run-id>.<attempt>`, with `-amd64`/`-arm64`
  staging suffixes. `php<VERSION>` and `latest` are mutable multi-platform aliases.
  Unique run IDs distinguish security rebuilds of the same source revision.
- There is no registry transaction across repositories. Partial alias promotion
  must fail visibly; a new dispatch can produce a complete new release.

## Security requirements

The 21 October 2026 PHP advisory identifies 8.2.35 as the fixed 8.2 release for
CVE-2026-109618 and CVE-2026-109619. Enforce PHP 8.2.35 or later for all images
and architectures. Verify current PHP and Red Hat vendor information when changing
versions. Never lower the floor without independently verified vendor-backport
documentation and a check of the exact fixed package release.

PHP 8.2 reaches upstream security end of life on 31 December 2026. Maintain the
README upgrade path to a supported branch (currently planned as separately named
8.5 images when UBI supports that branch). Branch migration also requires updating
the explicit 8.2 assertion in scripts/check-image.sh, not just versions.env.

UBI package updates must pass the PHP floor. If a fixed release or base is missing
for either architecture, fail before publishing; document the blocker and safe
retry via version review and workflow_dispatch. Never publish a misleading latest.

Never copy credentials, SSH keys, local environment files, application source or
unrelated assets into image contexts. Preserve context allowlists in .dockerignore.
Never add SSH-key injection hooks. Never put secrets in build
args, image layers, workflow output or logs. Use only GitHub Actions secrets
`DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`, with repository-scoped read/write access
where supported and no delete permission. Preserve non-root runtime defaults.
Install only packages/extensions needed for the defined image behavior; CLI
extension headers/helpers are intentionally retained for additional module builds.

## Validation

Run the narrowest relevant checks and fix only failures caused by the change.
For shell changes, run `bash -n scripts/*.sh`; check whitespace with
`git diff --check`. Do not run host PHP or install host build dependencies.

For full local builds, use Docker Desktop's emulation or configure Linux binfmt
as in CI. From the repository root:

```sh
docker build -t php-image-tools tools
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/work" -w /work php-image-tools scripts/build.sh
```

The tool wrapper supplies Bash/jq. Build checks create only disposable PHP image
validation containers. Never invoke scripts/publish.sh as a validation command.

`scripts/check-image.sh` checks php -v, CLI SAPI, minimum patch, expected extensions,
non-root user and common credential locations for each platform. UBI/dev also
check FPM version/config and run-cli's unlimited memory behavior. Dev checks
Composer, Xdebug and wait scripts. `scripts/check-manifest.sh` verifies published
manifests contain amd64 and arm64 (v8 when reported). Retain these checks and
reproducible inspection examples in README.md. Label illustrative output clearly;
never report actual image execution or publication without evidence.

## Known status and limitations

At initial implementation, shell syntax checks passed but Docker socket access
was denied. No image build, actual ARM64 execution or published manifest has been
verified in this session history. Check current evidence before claiming success.
The configured UBI tag's architecture availability and fixed PHP packages remain
unverified. Red Hat CVE pages were inaccessible; no backport exception was accepted.
The inherited UBI metrics script assumes cgroup v1. Keep limitations visible until
resolved with evidence; these statements are a starting point, not permanent facts.

## Git and delivery

SSH remote: `git@github.com:paha77/php-docker-images.git`; default branch: `main`.
Git is initialized. The initial README-only commit was pushed; implementation
files were left uncommitted, and README was subsequently revised. Always inspect
live Git status instead of assuming this snapshot is still current.

Do not commit, push, merge, rebase, modify remotes or create remote repositories
unless explicitly requested. Remotes must use SSH, never HTTPS workarounds.
The earlier README-only commit/push authorization was completed and is not ongoing
authorization. Do not publish images manually without explicit authorization.
Remember that pushing the workflow to the default branch enables automatic
publication if secrets are configured.

Update README.md when build behavior, tags, configuration, security policy or setup
changes. Report changed files, checks actually run, remaining blockers and required
developer setup. Never claim work was committed, pushed or published if it was not.
