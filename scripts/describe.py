"""Update Docker Hub overviews only after successful image publication."""
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote

from cleanup import BASE, request


def descriptions(branch, version, generation):
    namespace = os.environ.get("DOCKERHUB_NAMESPACE") or "paha77"
    source = "https://github.com/" + os.environ["GITHUB_REPOSITORY"]
    sha = os.environ["GITHUB_SHA"]
    run = os.environ["GITHUB_RUN_ID"]
    attempt = os.environ["GITHUB_RUN_ATTEMPT"]
    release = f"php{version}-{sha}-run{run}.{attempt}"
    php = version.rsplit(".", 1)[0]
    variants = (
        (f"php-{branch}-cli", "cli",
         f"PHP {php} CLI with GD, EXIF, mbstring, ZIP, GMP and BCMath.",
         "Official PHP CLI on Debian Bookworm; Europe/Vienna timezone; UID 1000:0."),
        (f"s2i-ubi{generation}-php{branch}", "ubi",
         f"PHP {php} Apache/FPM on UBI {generation} with S2I CLI runner and status hooks.",
         f"Red Hat UBI {generation}; Apache/FPM, S2I CLI runner, status/prelogin hooks; UID 1001."),
        (f"php-{branch}-dev", "dev",
         f"PHP {php} development image with Xdebug, Composer and wait scripts.",
         "Matching custom UBI parent built and validated in the same run; "
         "Xdebug, Composer, wait scripts and local UID aliases; UID 1001."),
    )
    for repo, kind, short, features in variants:
        overview = f"""# {namespace}/{repo}

{short}

{features}

## Source

- [GitHub repository]({source})
- [Dockerfile at this release]({source}/blob/{sha}/images/{kind}/Dockerfile)
- [Documentation and configuration]({source}/blob/{sha}/README.md)

## Latest published build

- Release: `{release}`
- [Source commit]({source}/commit/{sha})
- [Build and validation run]({source}/actions/runs/{run}/attempts/{attempt})
- Platforms: `linux/amd64`, `linux/arm64/v8`.
- Configured PHP minimum: `{version}`. UBI/dev may contain a newer patch in the same branch.
- Both platforms passed PHP version/security-floor, extension and non-root runtime checks.
- UBI/dev also passed FPM and CLI runner checks; dev passed Composer, Xdebug and wait-script checks.

## Tags

`latest` and `php{version}` follow the latest validated release.
Use the release tag above or a manifest digest to select a specific build.
Retention keeps the newest two complete release families and protects alias targets;
older release tags can be removed.

```dockerfile
FROM {namespace}/{repo}:{release}
```

This overview is generated after successful publication by GitHub Actions.
"""
        yield repo, {"description": short, "full_description": overview}


def main(args):
    if not args or len(args) % 3:
        raise ValueError("Expected branch/version/UBI-generation triples")
    # Prepare every payload before authenticating or changing repositories.
    payloads = [item for i in range(0, len(args), 3)
                for item in descriptions(*args[i:i + 3])]
    token = request(BASE + "/v2/auth/token", method="POST", data={
        "identifier": os.environ["DOCKERHUB_USERNAME"],
        "secret": os.environ["DOCKERHUB_TOKEN"],
    })["access_token"]
    namespace = quote(os.environ.get("DOCKERHUB_NAMESPACE") or "paha77", safe="")
    for repo, payload in payloads:
        path = f"/v2/repositories/{namespace}/{quote(repo, safe='')}"
        request(BASE + path, token, method="PATCH", data=payload)
        print(f"Updated Docker Hub overview: {repo}", flush=True)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except HTTPError as error:
        sys.exit(f"Docker Hub description update failed: HTTP {error.code}; check repository metadata access")
    except (URLError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"Docker Hub description update failed ({type(error).__name__}); no automatic retry")
