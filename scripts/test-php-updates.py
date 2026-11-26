#!/usr/bin/env python3
import importlib.util
import unittest
from unittest.mock import patch
from pathlib import Path
import tempfile
import os
import io

spec = importlib.util.spec_from_file_location('updates', 'scripts/check-php-updates.py')
updates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updates)


class PatchSelection(unittest.TestCase):
    def test_updates_only_pins_and_writes_review_body(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = os.getcwd()
            try:
                os.chdir(directory)
                original = 'declare -A PHP_VERSIONS=( [82]=8.2.35 [83]=8.3.37 )\nOTHER=keep\n'
                Path('versions.env').write_text(original)
                with patch.object(updates.sys, 'argv', ['check', '82=8.2.35', '83=8.3.37']), patch.object(
                    updates, 'urlopen', side_effect=[io.StringIO('{"8.2.36":{}}'), io.StringIO('{"8.3.37":{}}')]
                ):
                    updates.main()
                self.assertEqual(Path('versions.env').read_text(), original.replace('8.2.35', '8.2.36'))
                self.assertIn('8.2.35 → 8.2.36', Path('php-update-body.md').read_text())
            finally:
                os.chdir(previous)

    def test_later_fetch_failure_does_not_write_partial_update(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = os.getcwd()
            try:
                os.chdir(directory)
                original = 'declare -A PHP_VERSIONS=( [82]=8.2.35 [83]=8.3.37 )\n'
                Path('versions.env').write_text(original)
                with patch.object(updates.sys, 'argv', ['check', '82=8.2.35', '83=8.3.37']), patch.object(
                    updates, 'urlopen', side_effect=[io.StringIO('{"8.2.36":{}}'), OSError('offline')]
                ), self.assertRaises(OSError):
                    updates.main()
                self.assertEqual(Path('versions.env').read_text(), original)
                self.assertFalse(Path('php-update-body.md').exists())
            finally:
                os.chdir(previous)

    def test_numeric_patch_order(self):
        self.assertEqual(updates.latest_patch('8.4.9', {'8.4.10': {}}), '8.4.10')

    def test_never_downgrades(self):
        self.assertEqual(updates.latest_patch('8.4.27', {'8.4.26': {}}), '8.4.27')

    def test_current(self):
        self.assertEqual(updates.latest_patch('8.3.37', {'8.3.37': {}}), '8.3.37')

    def test_rejects_invalid_responses(self):
        for response in ({}, [], {'8.5.1': {}}, {'8.4.28RC1': {}}, {'bad': {}}):
            with self.subTest(response=response), self.assertRaises(ValueError):
                updates.latest_patch('8.4.27', response)


if __name__ == '__main__':
    unittest.main()
