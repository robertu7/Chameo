#!/usr/bin/env python3
"""Validate the effective grants in a release's signed entitlement plist."""
from pathlib import Path
import plistlib
import sys

REQUIRED_GRANTS = (
    'com.apple.security.app-sandbox',
    'com.apple.security.device.camera',
    'com.apple.security.personal-information.photos-library',
    'com.apple.security.personal-information.location',
    'com.apple.security.assets.pictures.read-write',
    'com.apple.security.files.user-selected.read-write',
    'com.apple.security.files.bookmarks.app-scope',
)
MACH_KEY = 'com.apple.security.temporary-exception.mach-lookup.global-name'


def validate(entitlements, bundle_id='com.robertu.Chameo'):
    for key in REQUIRED_GRANTS:
        if entitlements.get(key) is not True:
            raise ValueError(f'Signed entitlement must be boolean true: {key}')
    expected = {bundle_id + '-spks', bundle_id + '-spki'}
    names = entitlements.get(MACH_KEY)
    if (not isinstance(names, list) or not all(isinstance(name, str) for name in names)
            or set(names) != expected or len(names) != len(expected)):
        raise ValueError('Signed Sparkle Mach lookup names do not match the release bundle')


if __name__ == '__main__':
    try:
        validate(plistlib.loads(Path(sys.argv[1]).read_bytes()))
    except (ValueError, OSError) as error:
        sys.exit(str(error))
