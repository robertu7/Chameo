from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from update_homebrew_cask import update_cask


class HomebrewCaskTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.cask = self.root / "Casks/chameo.rb"

    def publish(self, version, contents=b"disk image"):
        disk_image = self.root / f"Chameo-{version}-arm64.dmg"
        disk_image.write_bytes(contents)
        update_cask(version, disk_image, self.cask)

    def test_initial_publication_and_identical_retry(self):
        self.publish("0.5.8")
        original = self.cask.read_bytes()
        self.publish("0.5.8")
        self.assertEqual(self.cask.read_bytes(), original)

    def test_upgrade_uses_numeric_version_order(self):
        self.publish("0.5.9")
        self.publish("0.5.10", b"new image")
        self.assertIn('version "0.5.10"', self.cask.read_text())

    def test_stale_retry_and_replaced_release_preserve_current_cask(self):
        self.publish("0.5.8")
        original = self.cask.read_bytes()
        for version, contents in (("0.5.7", b"older image"), ("0.5.8", b"changed image")):
            with self.subTest(version=version), self.assertRaises(ValueError):
                self.publish(version, contents)
            self.assertEqual(self.cask.read_bytes(), original)

    def test_prerelease_invalid_version_and_empty_image_are_rejected(self):
        for version in ("0.5.8-rc.1", "0.05.8", "v0.5.8"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                self.publish(version)
        with self.assertRaises(ValueError):
            self.publish("0.5.8", b"")
        self.assertFalse(self.cask.exists())
