#!/usr/bin/env python3
"""Resolve a published tag without mutating it; reuse its canonical asset bytes."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import subprocess
import sys
import tempfile
import zipfile


def validate_release(release, tag):
    version = tag[1:]
    if release['tag_name'] != tag or release['draft'] or release['prerelease'] != ('-' in version):
        raise ValueError('Published release metadata does not match the requested tag')
    expected = {f'Chameo-{version}-arm64.{suffix}' for suffix in ('zip', 'dmg', 'md')}
    assets = {asset['name']: asset for asset in release['assets']}
    if not expected <= assets.keys():
        raise ValueError('Published release is incomplete; refusing to replace its assets')
    return {name: assets[name] for name in expected}


def validate_download(path, asset):
    if path.stat().st_size != asset['size']:
        raise ValueError(f'Incorrect published asset size: {path.name}')
    digest = asset.get('digest')
    if digest is not None:
        actual = 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != actual:
            raise ValueError(f'Incorrect published asset digest: {path.name}')


def validate_archive(path, version, build_id, build_number):
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            name = PurePosixPath(item.filename)
            if name.is_absolute() or '..' in name.parts:
                raise ValueError('Unsafe path in published archive')
            # Sparkle contains relative framework symlinks. Check their destinations
            # before ditto extracts them; they must stay inside the staging folder.
            if (item.external_attr >> 16) & 0o170000 == 0o120000:
                target = archive.read(item).decode('utf-8')
                destination = os.path.normpath(str(name.parent / target))
                if target.startswith('/') or destination == '..' or destination.startswith('../'):
                    raise ValueError('Unsafe symlink in published archive')
        info = plistlib.loads(archive.read('Chameo.app/Contents/Info.plist'))
        if (info.get('ChameoMarketingVersion') != version
                or info.get('ChameoBuildID') != build_id
                or str(info.get('CFBundleVersion')) != str(build_number)):
            raise ValueError('Published archive does not match the immutable tagged source')


def recover(repo, tag, destination, build_id, build_number):
    if not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?', tag):
        raise ValueError('Invalid release tag')
    result = subprocess.run(['gh', 'api', f'repos/{repo}/releases/tags/{tag}'], capture_output=True, text=True)
    if result.returncode:
        if '(HTTP 404)' in result.stderr:
            return False
        raise RuntimeError('Unable to resolve the published release; refusing to treat an API failure as a missing tag')
    assets = validate_release(json.loads(result.stdout), tag)
    destination.mkdir(parents=True, exist_ok=True)
    subprocess.run(['gh', 'release', 'download', tag, '--repo', repo, '--dir', str(destination),
                    *[arg for name in sorted(assets) for arg in ('--pattern', name)]], check=True)
    for name, asset in assets.items():
        validate_download(destination / name, asset)
    archive = destination / f'Chameo-{tag[1:]}-arm64.zip'
    validate_archive(archive, tag[1:], build_id, build_number)
    with tempfile.TemporaryDirectory(prefix='chameo-published-') as staging:
        subprocess.run(['/usr/bin/ditto', '-x', '-k', str(archive), staging], check=True)
        env = dict(os.environ, CHAMEO_VERSION=tag[1:], CHAMEO_BUILD_ID=build_id,
                   CHAMEO_BUILD_NUMBER=build_number)
        subprocess.run([str(Path(__file__).with_name('verify_app_bundle.sh')),
                        str(Path(staging) / 'Chameo.app')], env=env, check=True)
    return True


if __name__ == '__main__':
    try:
        repo, tag, destination, build_id, build_number = sys.argv[1:]
        exists = recover(repo, tag, Path(destination), build_id, build_number)
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(f'exists={str(exists).lower()}\n')
            output.write(f'assets_dir={destination if exists else ""}\n')
    except (ValueError, RuntimeError, KeyError, OSError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        sys.exit(str(error))
