import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import recover_release_assets as recovery
import verify_entitlements as entitlements


class EntitlementTests(unittest.TestCase):
    def setUp(self):
        self.grants = {key: True for key in entitlements.REQUIRED_GRANTS}
        self.grants[entitlements.MACH_KEY] = ['com.robertu.Chameo-spki', 'com.robertu.Chameo-spks']

    def test_release_entitlements(self):
        entitlements.validate(self.grants)
        root = Path(__file__).resolve().parents[2]
        entitlements.validate(plistlib.loads((root / 'Chameo.entitlements').read_bytes()))

    def test_rejects_missing_false_or_non_boolean_grants(self):
        for key in entitlements.REQUIRED_GRANTS:
            for value in (False, 'true', 1, None):
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    bad = dict(self.grants, **{key: value})
                    entitlements.validate(bad)
            with self.subTest(missing=key), self.assertRaises(ValueError):
                bad = dict(self.grants)
                del bad[key]
                entitlements.validate(bad)

    def test_rejects_wrong_sparkle_names_and_broad_grants(self):
        for names in (True, [], [1, 2], [{}], ['com.robertu.Chameo-spks'], ['com.robertu.Chameo-spki', '*']):
            with self.subTest(names=names), self.assertRaises(ValueError):
                entitlements.validate(dict(self.grants, **{entitlements.MACH_KEY: names}))


class RecoveryTests(unittest.TestCase):
    def release(self):
        return {'tag_name': 'v0.5.6', 'draft': False, 'prerelease': False, 'assets': [
            {'name': f'Chameo-0.5.6-arm64.{suffix}', 'size': 3} for suffix in ('zip', 'dmg', 'md')]}

    def test_only_absent_tag_is_treated_as_new_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            for message, expected in [('gh: Not Found (HTTP 404)', False), ('network failure', None),
                                      ('gh: Bad credentials (HTTP 401)', None)]:
                with patch.object(recovery.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', message)):
                    if expected is False:
                        self.assertFalse(recovery.recover('owner/repo', 'v0.5.6', Path(directory), 'abc', '42'))
                    else:
                        with self.assertRaises(RuntimeError):
                            recovery.recover('owner/repo', 'v0.5.6', Path(directory), 'abc', '42')

    def test_existing_publication_uses_downloaded_assets_and_validates_source(self):
        release = self.release()
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            return subprocess.CompletedProcess(command, 0, json.dumps(release), '')
        with tempfile.TemporaryDirectory() as directory, patch.object(recovery.subprocess, 'run', side_effect=run), \
             patch.object(recovery, 'validate_download') as validate, \
             patch.object(recovery, 'validate_archive') as archive:
            self.assertTrue(recovery.recover('owner/repo', 'v0.5.6', Path(directory), 'abc', '42'))
            self.assertEqual(validate.call_count, 3)
            archive.assert_called_once_with(Path(directory) / 'Chameo-0.5.6-arm64.zip', '0.5.6', 'abc', '42')
            self.assertEqual(calls[1][:3], ['gh', 'release', 'download'])
            self.assertEqual(calls[2][:3], ['/usr/bin/ditto', '-x', '-k'])
            self.assertTrue(calls[3][0].endswith('verify_app_bundle.sh'))
            self.assertFalse(any('create' in command or 'upload' in command for command in calls))

    def test_incomplete_draft_wrong_channel_or_tag_rejected(self):
        for mutation in ({'draft': True}, {'prerelease': True}, {'tag_name': 'v0.5.5'}, {'assets': []}):
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                recovery.validate_release(dict(self.release(), **mutation), 'v0.5.6')

    def test_asset_size_and_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'asset.zip'
            path.write_bytes(b'abc')
            metadata = {'size': 3, 'digest': 'sha256:' + hashlib.sha256(b'abc').hexdigest()}
            recovery.validate_download(path, metadata)
            for changed in ({'size': 2}, {'digest': 'sha256:wrong'}):
                with self.assertRaises(ValueError):
                    recovery.validate_download(path, dict(metadata, **changed))

    def test_archive_symlink_cannot_escape_staging(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'asset.zip'
            metadata = {'ChameoMarketingVersion': '0.5.6', 'ChameoBuildID': 'abc', 'CFBundleVersion': '42'}
            for target in ('../../outside', '/outside', 'Versions/B'):
                with self.subTest(target=target):
                    with zipfile.ZipFile(path, 'w') as archive:
                        archive.writestr('Chameo.app/Contents/Info.plist', plistlib.dumps(metadata))
                        link = zipfile.ZipInfo('Chameo.app/link')
                        link.create_system = 3
                        link.external_attr = 0o120777 << 16
                        archive.writestr(link, target)
                    if target == 'Versions/B':
                        recovery.validate_archive(path, '0.5.6', 'abc', '42')
                    else:
                        with self.assertRaises(ValueError):
                            recovery.validate_archive(path, '0.5.6', 'abc', '42')

    def test_archive_source_identity_and_unsafe_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'asset.zip'
            info = {'ChameoMarketingVersion': '0.5.6', 'ChameoBuildID': 'abc', 'CFBundleVersion': '42'}
            def make_archive(metadata, extra=None):
                with zipfile.ZipFile(path, 'w') as archive:
                    archive.writestr('Chameo.app/Contents/Info.plist', plistlib.dumps(metadata))
                    if extra: archive.writestr(extra, b'bad')
            make_archive(info)
            recovery.validate_archive(path, '0.5.6', 'abc', '42')
            for key in info:
                with self.subTest(key=key), self.assertRaises(ValueError):
                    make_archive(dict(info, **{key: 'wrong'}))
                    recovery.validate_archive(path, '0.5.6', 'abc', '42')
            for unsafe in ('../outside', '/outside'):
                with self.subTest(path=unsafe), self.assertRaises(ValueError):
                    make_archive(info, unsafe)
                    recovery.validate_archive(path, '0.5.6', 'abc', '42')


class FeedRevisionTests(unittest.TestCase):
    def test_base_and_idempotent_deployment_allowed(self):
        import verify_feed_revision as revision
        revision.validate('a' * 64, 'a' * 64, 'b' * 64)
        revision.validate('b' * 64, 'a' * 64, 'b' * 64)
        revision.validate('absent', 'absent', 'b' * 64)

    def test_stale_or_missing_output_rejected(self):
        import verify_feed_revision as revision
        for current, base, published in [('c' * 64, 'a' * 64, 'b' * 64),
                                         ('absent', 'a' * 64, 'b' * 64),
                                         ('absent', 'absent', ''), ('a' * 64, '', 'b' * 64)]:
            with self.subTest(current=current), self.assertRaises(ValueError):
                revision.validate(current, base, published)
