# Agent instructions and repository context

## Scope

This is a standalone repository for building, validating and publishing six
reusable PHP images to Docker Hub. These instructions are sufficient to resume
work without conversation history. Do not inspect or modify external repositories
or consumers. Do not start application containers or deploy images.

| Image | Build context | Responsibility |
| --- | --- | --- |
| `paha77/php-82-cli` | `images/cli` | Official PHP CLI with GD, EXIF, mbstring, ZIP, GMP, BCMath; Europe/Vienna timezone; UID 1000:0 |
| `paha77/s2i-ubi9-php82` | `images/ubi` | UBI 9 Apache/FPM, S2I CLI runner, status/prelogin hooks; UID 1001 |
| `paha77/php-82-dev` | `images/dev` | Custom UBI plus Xdebug, Composer, wait scripts and UID aliases; UID 1001 |
| `paha77/php-84-cli` | `images/cli` | Same CLI behavior on PHP 8.4; UID 1000:0 |
| `paha77/s2i-ubi10-php84` | `images/ubi` | Same Apache/FPM and S2I behavior on UBI 10 PHP 8.4; UID 1001 |
| `paha77/php-84-dev` | `images/dev` | Fresh custom UBI 10 PHP 8.4 plus dev tools; UID 1001 |

CLI builds independently. Dev must consume the custom UBI image built for the
same branch and architecture in the same run, never an old published `latest`.
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

- `versions.env` centralizes PHP_BRANCHES, PHP_VERSIONS, UBI_BASES, UBI_GENERATIONS,
  XDEBUG_PACKAGES and COMPOSER_BASE using Bash 4+ arrays. Avoid
  duplicating version configuration. UBI bases deliberately use vendor `latest`
  tags, resolved by `--pull --no-cache` for each new build. Dev must still use its
  matching freshly validated local UBI parent/artifact from the same run.
  Keep official PHP CLI patches and Composer pinned, with deliberate updates.
- `scripts/build.sh` uses the default Buildx **docker driver**, loading separate
  `local/php-{cli,ubi,dev}:{82,84}-{amd64,arm64}` tags. Do not switch builders without
  preserving dev's ability to resolve the freshly built local UBI parent.
- Every image targets `linux/amd64` and `linux/arm64/v8`. ARM64 must actually
  execute, including on an emulated CI runner; an amd64-only build is insufficient.
- `.github/workflows/images.yml` builds all images on PRs and pushes. Default-branch
  pushes, Monday 05:23 UTC schedules and workflow_dispatch on the default branch
  publish after validation. Other branches and PRs never publish.
- CI derives branch/platform matrices from versions.env. CLI/UBI matrix jobs
  validate and upload image archives; dev matrix jobs load the matching validated
  UBI artifact from the same run. Docker push is a separate job gated on all builds.
  Image artifacts expire after one day; rerun the full workflow after expiration.
  scripts/build.sh accepts optional KIND BRANCH ARCH selectors; with no arguments
  it retains the full local build. Selected dev builds require the fresh UBI parent.
- GitHub-hosted Ubuntu runners use SHA-pinned checkout and QEMU actions. Review
  upstream action source and full commit IDs before updating pins.
- Artifact upload/download actions are also SHA-pinned. Keep downloads scoped to
  the current run, credentials confined to publication, and matrix fail-fast off.
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

The 21 October 2026 PHP advisory identifies 8.2.35 and 8.4.27 as the fixed releases for
CVE-2026-109618 and CVE-2026-109619. Enforce the corresponding branch and floor
for all images and architectures, independently of the configured build minimum.
Verify current PHP and Red Hat vendor information when changing
versions. Never lower the floor without independently verified vendor-backport
documentation and a check of the exact fixed package release.

PHP 8.2 reaches upstream security end of life on 31 December 2026. Maintain the
README upgrade path to the separately named 8.4 images (security support through
31 December 2028). PHP 8.5 is deferred until UBI provides it. Adding branches also
requires updating the supported branch/floor map in scripts/check-image.sh,
not just versions.env.

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

On 22 October 2026, UBI 9 with updated PHP 8.2.35 passed the full existing checks
on amd64 and arm64/v8 after restoring runner configuration/log permissions.
The amd64 build used no cache. PHP 8.2 dev passed on both architectures with each
fresh UBI parent. This supersedes the historical UBI 9 floor blocker below. The latest CI
run before the fix passed the floor but failed the CLI memory check following
permission errors; publication was skipped. PHP 8.4 blockers were not rechecked.

Shell syntax and whitespace checks passed. Docker tools and image builds were
executed. PHP 8.2.35 CLI passed on amd64; PHP 8.4.27 CLI passed on amd64 and ARM64.
The full build failed on the updated UBI 9 amd64 image reporting PHP 8.2.33.
The previously pinned UBI 10 PHP 8.4 manifest includes amd64 and arm64/v8. Both custom UBI 10
builds executed PHP 8.4.24 and failed the floor after package updates; separate
FPM, extension and unlimited-memory CLI runner checks passed on both platforms.
The ARM64 8.4 dev build failed on the unavailable matching Xdebug package. Review
the configured package name when Red Hat supplies it. Do not lower the floor or
install an Xdebug package for PHP 8.3 to work around these release blockers.
Negative security-gate tests rejected a lowered minimum and mismatched branch.
Red Hat CVE pages were inaccessible; no backport exception was accepted. Dev
runtime validation, a complete successful build and published manifests remain
unverified. No images were published in these checks. The inherited UBI metrics
script assumes cgroup v1. Update these limitations only with new evidence.

## Git and delivery

Keep repository content suitable for public disclosure. Do not include private
project names, paths, domains, infrastructure details, credentials, or personal
contact information other than the approved Git author name/email. Audit history
and GitHub metadata before making the repository public; a later deletion does not
remove information from earlier commits.

SSH remote: `git@github.com:paha77/php-docker-images.git`; default branch: `main`.
Git is initialized. Always inspect live Git status and remote history before
making changes; do not assume local and remote history match.

Always create a local Git commit after creating or closing a bigger milestone
(a substantial, coherent unit of work). This rule authorizes milestone commits
without asking again. Run the relevant checks, review the diff, and stage only
changes belonging to that milestone; preserve unrelated uncommitted user changes.
After each milestone commit, report the commit and ask the user whether to push it.
Do not push until the user explicitly approves.

Outside milestone commits, do not commit unless explicitly requested. Do not
merge, rebase, modify remotes or create remote repositories unless explicitly
requested. Remotes must use SSH, never HTTPS workarounds. The earlier README-only
commit/push authorization was completed and is not ongoing push authorization.
Do not publish images manually without explicit authorization.
Remember that pushing the workflow to the default branch enables automatic
publication if secrets are configured.

Update README.md when build behavior, tags, configuration, security policy or setup
changes. Report changed files, checks actually run, remaining blockers and required
developer setup. Never claim work was committed, pushed or published if it was not.
