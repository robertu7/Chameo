import base64
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
root = Path(__file__).resolve().parents[3]
with tempfile.TemporaryDirectory(prefix='chameo-recovery-packaging-') as staging:
    staging = Path(staging)
    shutil.copytree(root / 'script', staging / 'script')
    for name in ['VERSION', 'CHANGELOG.md']:
        shutil.copy2(root / name, staging / name)
    (staging / 'dist').mkdir()
    subprocess.run(['/usr/bin/ditto', str(root / 'dist/Chameo.app'), str(staging / 'dist/Chameo.app')], check=True)
    # Match the fixture app and verifier to the public RFC 8032 test key.
    public_key = '11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo='
    import plistlib
    plist_path = staging / 'dist/Chameo.app/Contents/Info.plist'
    info = plistlib.loads(plist_path.read_bytes())
    original_public_key = info['SUPublicEDKey']
    info['SUPublicEDKey'] = public_key
    plist_path.write_bytes(plistlib.dumps(info))
    verify_script = staging / 'script/verify_app_bundle.sh'
    verify_script.write_text(verify_script.read_text().replace(original_public_key, public_key))
    subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-', '--entitlements',
                    str(root / 'Chameo.entitlements'), str(staging / 'dist/Chameo.app')], check=True)
    (staging / '.build').mkdir()
    shutil.copytree(root / '.build/artifacts/sparkle/Sparkle', staging / '.build/artifacts/sparkle/Sparkle')
    key = staging / 'test-key'
    key.write_bytes(base64.b64encode(bytes.fromhex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60')))
    key.chmod(0o600)
    env = dict(os.environ, SPARKLE_PRIVATE_KEY_FILE=str(key))
    version = (root / 'VERSION').read_text().strip()
    subprocess.run([str(staging / 'script/prepare_release.sh'), version], env=env, check=True)
    canonical = staging / 'canonical'
    canonical.mkdir()
    files = [staging / f'dist/updates/Chameo-{version}-arm64.zip', staging / f'dist/updates/Chameo-{version}-arm64.md', staging / f'dist/releases/Chameo-{version}-arm64.dmg']
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    for p in files: shutil.copy2(p, canonical / p.name)
    env['CHAMEO_REUSE_RELEASE_ASSETS_DIR'] = str(canonical)
    subprocess.run([str(staging / 'script/prepare_release.sh'), version], env=env, check=True)
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    print('recovery_preserves_zip_dmg_notes_bytes=passed')
