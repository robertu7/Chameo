#!/usr/bin/env python3
"""Exercise release feed finalization with Sparkle and temporary test keys."""

import base64
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def main():
    tool = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="chameo-feed-test-") as directory:
        directory = Path(directory)
        key = directory / "test-key"
        # RFC 8032 test vector; never access the production signing key.
        key.write_bytes(base64.b64encode(bytes.fromhex(
            "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")))
        key.chmod(0o600)
        public_key = base64.b64encode(bytes.fromhex(
            "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")).decode()
        verifier = directory / "verify-appcast"
        run("swiftc", str(ROOT / "script/verify_appcast.swift"), "-o", str(verifier))
        def reject(feed, public=public_key):
            result = subprocess.run([str(verifier), str(feed), public], capture_output=True)
            assert result.returncode != 0, "invalid feed was accepted"
        for version in ("0.5.0", "0.5.0-rc.0"):
            archive = f"Chameo-{version}-arm64.zip"
            feed = directory / "appcast.xml"
            feed.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel><item>
    <title>Version 0.5.0</title>
    <sparkle:shortVersionString>0.5.0</sparkle:shortVersionString>
    <enclosure url="https://example.test/{archive}" />
  </item></channel>
</rss>
''')
            reject(feed)
            run(str(tool), "--ed-key-file", str(key), str(feed))
            run(str(tool), "--verify", "--ed-key-file", str(key), str(feed))
            run("bash", str(ROOT / "script/finalize_appcast.sh"), str(feed),
                archive, version, str(tool), "--ed-key-file", str(key))
            run(str(tool), "--verify", "--ed-key-file", str(key), str(feed))
            content = feed.read_text()
            run(str(verifier), str(feed), public_key)
            reject(feed, base64.b64encode(os.urandom(32)).decode())
            assert f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>" in content
            assert f"<title>Version {version}</title>" in content
            feed.write_text(content.replace("example.test", "example.fail"))
            reject(feed)
            feed.write_text(content.replace("</rss>", "</rss>\n"))
            reject(feed)
            print(f"signed_feed_{version}=passed")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        print(error.stdout + error.stderr, file=sys.stderr)
        sys.exit(1)
