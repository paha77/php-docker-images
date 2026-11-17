import importlib.util
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("cleanup", "scripts/cleanup.py")
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


def release(number):
    name = f"php8.2.35-{'a' * 40}-run{number}.1"
    return [dict(name=name, digest=f"index{number}", tag_last_pushed=f"2026-11-{number:02}T00:00:00Z",
                 images=[dict(os="linux", architecture=a, digest=f"{number}{a}")
                         for a in ("amd64", "arm64")])] + [
        dict(name=name + "-" + a, digest=f"{number}{a}") for a in ("amd64", "arm64")]


class CleanupTests(unittest.TestCase):
    def tags(self):
        return sum((release(n) for n in (1, 2, 3)), []) + [
            dict(name="latest", digest="index3"), dict(name="php8.2.35", digest="index3")]

    def test_keeps_two_and_unknown_tags(self):
        tags = self.tags() + [dict(name="custom", digest="custom")]
        self.assertEqual(cleanup.candidates(tags), [t["name"] for t in release(1)])

    def test_alias_protects_older_family(self):
        tags = self.tags() + [dict(name="php8.2.34", digest="index1")]
        self.assertEqual(cleanup.candidates(tags), [])

    def test_incomplete_release_preserved(self):
        tags = self.tags()
        tags.remove(tags[1])
        self.assertEqual(cleanup.candidates(tags), [])

    def test_insufficient_releases_fail(self):
        with self.assertRaises(ValueError):
            cleanup.candidates(release(1))

    def test_missing_latest_fails(self):
        with self.assertRaises(ValueError):
            cleanup.candidates(sum((release(n) for n in (1, 2, 3)), []))

    @patch.dict("os.environ", DOCKERHUB_USERNAME="test", DOCKERHUB_TOKEN="secret")
    def test_pagination_and_deletes(self):
        calls = []
        def api(url, token=None, method="GET", data=None):
            calls.append((url, method))
            if method == "POST":
                return {"access_token": "bearer"}
            if method == "DELETE":
                return None
            if "page=2" in url:
                return {"results": self.tags()[3:], "next": None}
            return {"results": self.tags()[:3], "next": url + "&page=2"}
        with patch.object(cleanup, "request", side_effect=api):
            cleanup.main(["php-82-cli"])
        self.assertEqual(sum(method == "DELETE" for _, method in calls), 3)

    @patch.dict("os.environ", DOCKERHUB_USERNAME="test", DOCKERHUB_TOKEN="secret")
    def test_inventory_failure_prevents_all_deletes(self):
        with patch.object(cleanup, "request", side_effect=[
                {"access_token": "bearer"}, {"results": self.tags(), "next": None},
                ValueError("failed")]) as api:
            with self.assertRaises(ValueError):
                cleanup.main(["php-82-cli", "php-82-dev"])
        self.assertFalse(any(call.kwargs.get("method") == "DELETE" for call in api.call_args_list))


unittest.main()
