"""Retain the newest two complete releases; delete only older release tags."""
import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, build_opener, HTTPRedirectHandler

BASE = "https://hub.docker.com"
RELEASE = re.compile(r"php\d+\.\d+\.\d+-[0-9a-f]{40}-run\d+\.\d+")


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(url, token=None, method="GET", data=None):
    if not url.startswith(BASE + "/v2/"):
        raise ValueError("Unexpected Docker Hub API URL")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = Request(url, headers=headers, method=method,
                  data=None if data is None else json.dumps(data).encode())
    with build_opener(NoRedirect).open(req, timeout=60) as response:
        body = response.read()
        return json.loads(body) if body else None


def candidates(tags):
    by_name = {tag["name"]: tag for tag in tags}
    releases = [tag for tag in tags if RELEASE.fullmatch(tag["name"])]
    complete = []
    for tag in releases:
        name = tag["name"]
        images = {im["architecture"]: im["digest"] for im in tag["images"]
                  if im.get("os") == "linux"}
        if all(images.get(arch) and
               by_name.get(name + "-" + arch, {}).get("digest") == images[arch]
               for arch in ("amd64", "arm64")):
            complete.append(tag)
    if len(complete) < 2:
        raise ValueError("Fewer than two complete releases; refusing cleanup")
    complete.sort(key=lambda tag: tag["tag_last_pushed"], reverse=True)
    keep = {tag["name"] for tag in complete[:2]}
    aliases = [tag for tag in tags if tag["name"] == "latest" or
               re.fullmatch(r"php\d+\.\d+\.\d+", tag["name"])]
    if not any(tag["name"] == "latest" and tag.get("digest") for tag in aliases):
        raise ValueError("Missing latest digest; refusing cleanup")
    # Preserve release families referenced by aliases, even following partial promotion.
    protected = {tag["digest"] for tag in aliases if tag.get("digest")}
    keep.update(tag["name"] for tag in releases if tag.get("digest") in protected)
    result = []
    for tag in complete[2:]:
        if tag["name"] not in keep:
            result.extend(tag["name"] + suffix for suffix in ("", "-amd64", "-arm64"))
    return result


def main(repositories):
    namespace = os.environ.get("DOCKERHUB_NAMESPACE") or "paha77"
    token = request(BASE + "/v2/auth/token", method="POST", data={
        "identifier": os.environ["DOCKERHUB_USERNAME"],
        "secret": os.environ["DOCKERHUB_TOKEN"],
    })["access_token"]
    plans = []
    # Inventory every repository before deleting anything. Follow all pages.
    for repo in repositories:
        path = f"/v2/repositories/{quote(namespace, safe='')}/{quote(repo, safe='')}/tags/"
        url = BASE + path + "?page_size=100"
        tags, seen = [], set()
        while url:
            if url in seen or not url.startswith(BASE + path):
                raise ValueError("Invalid Docker Hub pagination")
            seen.add(url)
            page = request(url, token)
            tags.extend(page["results"])
            url = page["next"]
        plans.append((repo, path, candidates(tags)))
    for repo, path, names in plans:
        for name in names:
            request(BASE + path + quote(name, safe='') + "/", token, method="DELETE")
            print(f"Deleted {namespace}/{repo}:{name}", flush=True)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except HTTPError as error:
        sys.exit(f"Docker Hub cleanup failed: HTTP {error.code}; check delete access and tag immutability")
    except (URLError, ValueError, KeyError, TypeError) as error:
        # Never print API responses, credentials or request headers.
        sys.exit(f"Docker Hub cleanup failed ({type(error).__name__}); no automatic retry")
